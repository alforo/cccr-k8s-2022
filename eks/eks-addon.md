# EKS 클러스터: Addon 구성
> 작성일자: 2021-02-18
> 수정일자: 2022-06-01

---

## 1. ALB Ingress Controller

> [AWS Load Balancer Controller - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
> [Create an IAM OIDC provider for your cluster - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)

### 사전 요구 사항
* 클러스터용 IAM OIDC 공급자
	* iam.withOIDC: true
* ALB를 위한 IAM 정책 생성
	* managedNodeGroups.iam.withAddonPolicies.albIngress: true
* AWSLoadBalancerControllerIAMPolicy 정책과 연결된 aws-load-balancer-controller 서비스 계정 생성
	* iam.serviceAccounts.metadata.name: aws-load-balancer-controller
	* iam.serviceAccounts.wellKnownPolicies.awsLoadBalancerController: true

### TargetGroupBinding CRD 리소스 설치
```
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
```

### EKS 차트 저장소 추가
```
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

### aws-load-balancer-controller 차트 설치
```
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=myeks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  -n kube-system
```

> eksctl로 클러스터 생성시 aws-load-balancer-controller SA 계정을 이미 생성 했으므로 생성하지 않음

### ALB Ingress Controller 리소스 확인
```
$ kubectl get deployment -n kube-system aws-load-balancer-controller

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   1/1     1            1           91s
```

---

## 2. EBS CSI Driver

> [Amazon EBS CSI driver - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
> https://github.com/kubernetes-sigs/aws-ebs-csi-driver

### 사전 요구 사항
	* 클러스터에 IAM OIDC 공급자 구성
	* 워커 노드에 EBS CSI에 대한 정책 생성
		* managedNodeGroups.iam.withAddonPolicies.ebs: true
	* EBS CSI 정책과 연결된 ebs-csi-controller-sa 서비스 계정 생성
		* iam.serviceAccounts.metadata.name: ebs-csi-controller-sa
		* iam.serviceAccounts.wellKnownPolicies.ebsCSIController: true

### Helm 차트 저장소 추가
```
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
```

### 패키지 설치
```
helm upgrade -i aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set enableVolumeResizing=true \
  --set enableVolumeSnapshot=true \
  --set serviceAccount.controller.create=false \
  --set serviceAccount.controller.name=ebs-csi-controller-sa
```

> serviceAccount.controller -> controller.serviceAccount

### EBS CSI 관련 리소스 확인
```
$ kubectl get pod -n kube-system -l "app.kubernetes.io/name=aws-ebs-csi-driver,app.kubernetes.io/instance=aws-ebs-csi-driver"

NAME                                 READY   STATUS    RESTARTS   AGE
ebs-csi-controller-d4bff6587-7nbsk   6/6     Running   0          55s
ebs-csi-controller-d4bff6587-k2m8f   6/6     Running   0          55s
ebs-csi-node-kxsb5                   3/3     Running   0          55s
ebs-csi-node-s7c2m                   3/3     Running   0          55s
ebs-csi-node-wgrbs                   3/3     Running   0          55s
ebs-snapshot-controller-0            1/1     Running   0          55s
```

---

## 3. Metrics Server

> [Installing the Kubernetes Metrics Server - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html)

### Metrics Server 리소스 배포
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Metric Server 디플로이먼트 리소스 확인
```
$ kubectl get deployment metrics-server -n kube-system

NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           52s
```

---

## 4. Cluster AutoScaler

> [Cluster Autoscaler - Amazon EKS](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/cluster-autoscaler.html)

### 사전 요구 사항
* 노드 그룹에 대한 `Auto Scaling Groups`의 태그:
	* k8s.io/cluster-autoscaler/enabled
	* k8s.io/cluster-autoscaler/`<CLUSTER-NAME>`
* 워커 노드에 ClusterAutoScaler 관련 IAM 정책 생성
	* managedNodeGroups.iam.withAddonPolicies.autoScaler: true
* Cluster Autoscaler 정책과 연결된  cluster-autoscaler 서비스 계정 생성
	* iam.serviceAccounts.metadata.name: cluster-autoscaler
	* iam.serviceAccounts.wellKnownPolicies.autoScaler: true

### Cluster AutoScaler 디플로이먼트 메니페스트 다운로드
```
wget https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

### 클러스터 이름 수정, 옵션 추가, 이미지 버전 변경
```
vi cluster-autoscaler-autodiscover.yaml

...    
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
        - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.23.1
...
          command:
            - ./cluster-autoscaler
            - --v=4
            - --stderrthreshold=info
            - --cloud-provider=aws
            - --skip-nodes-with-local-storage=false
            - --expander=least-waste
            - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<YOUR CLUSTER NAME>
            - --balance-similar-node-groups
...
```

* 클러스터 이름 수정
	* `<YOUR CLUSTER NAME>` 부분에 해당 클러스터 이름 지정
* 옵션 추가
	* --balance-similar-node-groups
	* --skip-nodes-with-system-pods=false
* 컨테이너 이미지 버전 변경
	* 클러스터 버전과 동일한 버전 지정
	* [Releases · kubernetes/autoscaler · GitHub](https://github.com/kubernetes/autoscaler/releases)

### Cluster AutoScaler 리소스 생성
```
kubectl apply -f cluster-autoscaler-autodiscover.yaml
```

> SA 계정 및 RBAC 이미 존재하는 경우 해당 내용 제거

### 로그 확인
```
kubectl logs -f deployment/cluster-autoscaler -n kube-system
```
오류가 없는지 확인

---

## 5. CloudWatch Container Insights

> [Setting Up Container Insights on Amazon EKS and Kubernetes - Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-EKS.html)
> [Quick Start Setup for Container Insights on Amazon EKS and Kubernetes - Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-quickstart.html)
> [Set Up the CloudWatch Agent to Collect Cluster Metrics - Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-metrics.html)

* CloudWatch Container Insights는 노드, 컨테이너 및 애플리케이션의 지표(Metric) 및 로그를 수집
* CPU, Memory, Disk, Network 등 여러 리소스에 대한 지표를 자동으로 수집
* 수집된 지표에 대해 CloudWatch 경보 설정
* 수집된 지표는 CloudWatch 대시보드에서 모니터링 가능

### 사전 요구 사항
* 워커 노드에 CloudWatchAgentServerPolicy 정책 연결 필요
	* managedNodeGroups.iam.withAddonPolicies.cloudWatch: true

### CloudWatch 에이전트 및 Fluent Bit 배포
> FluentD로 배포하는 방법도 있으며, 성능 및 리소스 사용량에 있어 Fluent Bit가 이점이 있음

```bash
ClusterName=<my-cluster-name>
RegionName=<my-cluster-region>
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${RegionName}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f - 
```
쉘 변수 설정: ClusterName 및 RegionName 변수의 값을 설정하고 실행
> ClusterName=mykes
> RegionName=ap-northeast-2

```bash
ClusterName=myeks
RegionName=us-east-1
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${RegionName}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f - 
```

### CloudWatch 에이전트 및 Fluent Bit 리소스 확인
```
$ kubectl get po -n amazon-cloudwatch

NAME                     READY   STATUS    RESTARTS   AGE
cloudwatch-agent-2q7tj   1/1     Running   0          31s
cloudwatch-agent-kgh9j   1/1     Running   0          31s
cloudwatch-agent-qfkvq   1/1     Running   0          31s
fluent-bit-8zzmr         1/1     Running   0          23s
fluent-bit-cgdhv         1/1     Running   0          23s
fluent-bit-cmpkn         1/1     Running   0          23s
```

### CloudWatch 로그 및 성능 모니터링

#### 로그
`CloudWatch -> 로그 -> 로그 그룹`
* /aws/containerinsights/myeks/application
* /aws/containerinsights/myeks/host
* /aws/containerinsights/myeks/performance

#### 성능 모니터링
`CloudWatch -> Container Insights -> 성능 모니터링`
