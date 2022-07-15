# eksctl을 이용한 Amazon EKS 클러스터 생성 및 관리

> 작성일자: 2021-02-18
> 수정일자: 2022-04-01
---

## 1. eksctl 이란?

> https://eksctl.io
> https://github.com/weaveworks/eksctl

Amazon EKS를 위한 공식 CLI 도구
weaveworks에서 golang으로 개발한 오픈소스

제공되는 기능:
* 클러스터 생성, 확인, 목록, 삭제
* 노드그룹 생성, 드레인, 삭제
* 노드그룹 크기조정
* 클러스터 업데이트
* 커스텀 AMI 사용
* VPC 네트워크 구성
* API Endpoint 접근 구성
* GPU 노드그룹 지원
* 온디멘드 / 스팟 / 혼합 인스턴스
* IAM 관리 및 Add-on 정책
* CloudFormation 스택 클러스터 목록
* CoreDNS 설치
* kubeconfig 파일 쓰기

---

## 2. EKS 클러스터 생성 기본

### CLI 명령 사용

```bash
eksctl create cluster
```

* 기본 파라미터
	* 클러스터 이름 자동 생성 (예: fabulous-party-1613531171)
	* 2개의 m5.large 워커 노드
	* 공식 AWS EKS AMI 사용
	* us-west-2 리전 사용
	* 전용 VPC 사용

### CLI 명령 사용자화

```bash
eksctl create cluster \
	--name mycluster \
	--region ap-northeast-2 \
	--version 1.22 \
	--nodegroup-name mynodegroup
	--nodes 3 \
	--nodes-min 2 \
	--nodes-max 4 \
	--managed
```

### 구성 파일 사용

구성 파일을 사용하여 클러스터 사용자화
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: mycluster
  region: ap-northeast-2

nodeGroups:
  - name: ng-1
    instanceType: m5.large
    desiredCapacity: 2
  - name: ng-2
    instanceType: m5.xlarge
    desiredCapacity: 2
```

구성 파일을 사용하여 클러스터 생성
```bash
eksctl create cluster -f cluster.yaml
```

---

## 3. eksctl 구성 파일

### 구성 파일 예제

> eks-cluster-example.yaml
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: mycluster
  region: ap-northeast-2
  version: "1.22"

#AZ
availabilityZones: ["ap-northeast-2a", "ap-northeast-2b",  "ap-northeast-2c", "ap-northeast-2d"]

# IAM OIDC & Service Account
iam:
  withOIDC: true
  serviceAccounts:
    - metadata:
        name: aws-load-balancer-controller
        namespace: kube-system
      wellKnownPolicies:
        awsLoadBalancerController: true
    - metadata:
        name: ebs-csi-controller-sa
        namespace: kube-system
      wellKnownPolicies:
        ebsCSIController: true
    - metadata:
        name: cluster-autoscaler
        namespace: kube-system
      wellKnownPolicies:
        autoScaler: true

# Unmanaged Node Groups
nodeGroups:
  # On-Demand Instance / Public Network / SSH
  - name: ng-1
    instanceType: t2.small
    desiredCapacity: 1
    availabilityZones: ["ap-northeast-2a", "ap-northeast-2b"]
    ssh:
      allow: true
      publicKeyPath: ./eks-key.pub

  # Spot Instances / Scaling / Private Network
  # IAM Policy: AutoScaler, ALB Ingress, CloudWatch, EBS
  - name: ng-spot-2
    minSize: 1
    desiredCapacity: 2
    maxSize: 3
    privateNetworking: true
    instancesDistribution:
      maxPrice: 0.01
      instanceTypes: ["t2.small", "t3.small"]
      onDemandBaseCapacity: 0
      onDemandPercentageAboveBaseCapacity: 0
      spotInstancePools: 2
    availabilityZones: ["ap-northeast-2c", "ap-northeast-2d"]
    iam:
      withAddonPolicies:
        autoScaler: true
        albIngress: true
        cloudWatch: true
        ebs: true

  # Mixed(On-Demand/Spot) Instances
  - name: ng-mixed-3
    desiredCapacity: 2
    instancesDistribution:
      maxPrice: 0.01
      instanceTypes: ["t2.small", "t3.small"]
      onDemandBaseCapacity: 1
      onDemandPercentageAboveBaseCapacity: 50

# Managed Node Groups
managedNodeGroups:
  # On-Demand Instance
  - name: managed-ng-1
    instanceType: t2.small
    desiredCapacity: 2

  # Spot Instance
  - name: managed-ng-spot-2
    instanceTypes: ["t2.medium", "t3.medium"]
    desiredCapacity: 1
    spot: true

# Fargate Profiles
fargateProfiles:
  - name: fg-1
    selectors:
    - namespace: dev
      labels:
        env: fargate

# CloudWatch Logging
cloudWatch:
  clusterLogging:
    enableTypes: ["api", "scheduler"]
```

### 클러스터 기본 설정

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: mycluster
  region: ap-northeast-2
  version: "1.22"

#AZ
availabilityZones: ["ap-northeast-2a", "ap-northeast-2b",  "ap-northeast-2c", "ap-northeast-2d"]
```

* metadata
	* name: EKS 클러스터 이름
	* region: EKS 클러스터를 생성할 리전 (기본: us-west-2)
	* version: EKS 클러스터 버전, 선택하지 않으면 현재 시점의 기본 버전이 선택됨
* availabilityZones: VPC의 서브넷을 생성할 AZ, 선택하지 않으면 랜덤한 2개의 AZ가 선택됨, AZ 마다 퍼블릭 서브넷과 프라이빗 서브넷 생성된

### 노드 그룹

노드 그룹은 하나 이상의 EC2 인스턴스의 모음

#### 비 관리(Unmanaged)형 노드 그룹

"비 관리형 노드 그룹"은 eksctl 도구가 처음부터 지원했고, 기본적으로 사용 되는 노드 그룹
"관리형 노드 그룹"이 새롭게 추가되면서 "비 관리형 노드 그룹"이란 용어로 사용됨

#### 관리(Managed)형 노드 그룹

"관리형 노드 그룹"은 EKS 클러스터 노드(EC2)의 프로비저닝 및 수명주기 관리를 자동화

관리형 노드 그룹 특징:
	* 자동 확장 그룹 사용
	* EKS에 최적화된 Amazon Linux 2 AMI 사용
	* OS의 버그 수정 및 보안 패치를 쉽게 적용가능
	* 최신 Kubernetes 버전으로 업데이트 가능

### IAM 사용자 및 ServiceAccounts

```yaml
# IAM OIDC & Service Account
iam:
  withOIDC: true
  serviceAccounts:
    - metadata:
        name: aws-load-balancer-controller
        namespace: kube-system
      wellKnownPolicies:
        awsLoadBalancerController: true
    - metadata:
        name: ebs-csi-controller-sa
        namespace: kube-system
      wellKnownPolicies:
        ebsCSIController: true
    - metadata:
        name: cluster-autoscaler
        namespace: kube-system
      wellKnownPolicies:
        autoScaler: true       
```

* iam: 클러스터의 IAM 관련 속성 정의
	* withOIDC: 
		* IRSA(IAM roles for service accounts)를 위한 IAM OIDC(OpenID Connect) 공급자 활성 여부 (기본: false)
	* serviceAccounts: 클러스터에 생성할 서비스 계정 정의
		* metadata
			* name: 생성할 서비스 계정 이름
			* namespace: 서비스 계정이 속할 네임스페이스
		* wellKnownPolicies: 연결할 일반적인 IAM 정책
			* imageBuilder, autoScaler, awsLoadBalancerController, externalDNS, certManager


### 비관리형 노드 그룹: 온디멘드 인스턴스

```yaml
# Unmanaged Node Groups
nodeGroups:
  # On-Demand Instance / Public Network / SSH
  - name: ng-1
    instanceType: t2.small
    desiredCapacity: 1
    availabilityZones: ["ap-northeast-2a", "ap-northeast-2b"]
    ssh:
      allow: true
      publicKeyPath: ./eks-key.pub
```

* nodeGroups:
	* name: 노드 그룹 이름
	* instanceType: EC2 인스턴스 타입 (기본: m5.large) 
	* availabilityZones: EC2 인스턴스가 생성될 AZ
	* ssh
		* allow: ssh 접속 허용 여부 (기본: false)
		* publicKeyPath: SSH 공개키 파일 위치 (파일이 미리 존재해야함)

### 비관리형 노드 그룹: 스팟 인스턴스

```yaml
nodeGroups: 
...
# Spot Instances / Scaling / Private Network
  # IAM Policy: AutoScaler, ALB Ingress, CloudWatch, EBS
  - name: ng-spot-2
    minSize: 1
    desiredCapacity: 2
    maxSize: 3
    privateNetworking: true
    instancesDistribution:
      maxPrice: 0.01
      instanceTypes: ["t2.small", "t3.small"]
      onDemandBaseCapacity: 0
      onDemandPercentageAboveBaseCapacity: 0
      spotInstancePools: 2
    availabilityZones: ["ap-northeast-2c", "ap-northeast-2d"]
    iam:
      withAddonPolicies:
        autoScaler: true
        albIngress: true
        cloudWatch: true
        ebs: true
```

* nodeGroups
	* minSize: 최소 인스턴스 개수, 지정하지 않으면 desiredCapacity와 같음
	* desiredCapacity: 인스턴스 개수
	* maxSize: 최대 인스턴스 개수
	* privateNetworking: 인스턴스를 프라이빗 네트워크에 배치 여부 (기본: false)
	* instancesDistribution: (비 관리형 노드 그룹) 스팟 인스턴스 정의
		* maxPrice: 시간당 최고 가격 지정
		* instanceTypes: 스팟 인스턴스에 사용할 인스턴스 타입
		* onDemandBaseCapacity: 온디멘드 인스턴스 개수
		* onDemandPercentageAboveBaseCapacity: 온디멘드 인스턴스 비율
		* spotInstancePools: 같은 유형, 운영체제, AZ, 네트워크를 가지는 풀의 개수
	* iam: 노드의 IAM 속성 정의
		* withAddonPolicies: Addon에 대한 IAM 정책 정의
			* autoScaler: Cluster Autoscaler
			* albIngress: ALB Ingress
			* cloudWatch: CloudWatch
			* ebs: EBS

### 관리형 노드 그룹: 온디멘드 인스턴스

```yaml
# Managed Node Groups
managedNodeGroups:
  # On-Demand Instance
  - name: managed-ng-1
    instanceType: t2.small
    desiredCapacity: 2
```

* managedNodeGroups: 관리형 노드 그룹 정의

### 관리형 노드 그룹: 스팟 인스턴스

```yaml
# Managed Node Groups
managedNodeGroups:
...
  # Spot Instance
  - name: managed-ng-spot-2
    instanceTypes: ["t2.medium", "t3.medium"]
    desiredCapacity: 1
    spot: true
```

* managedNodeGroups
	* instanceTypes: 인스턴스 타입들 정의 (기존의 instanceType 이 아님)
	* spot: 스팟 인스턴스 사용 여부 (비 관리형 노드 그룹과 스팟 인스턴스 정의가 다름)

### Fargate 프로파일

```yaml
# Fargate Profiles
fargateProfiles:
  - name: fg-1
    selectors:
    - namespace: dev
      labels:
        env: fargate
```

* fargateProfiles: Fargate 프로파일 정의
	* name: 프로파일 이름
	* selectors: Fargate가 워크로드를 스케줄링하기 위한 선택기
		* namespaces: 워크로드의 네임스페이스
		* labels: 워크로드의 레이블

### Control Plane의 CloudWatch 로깅
```yaml
# CloudWatch Logging
cloudWatch:
  clusterLogging:
    enableTypes: ["api", "scheduler"]
```

EKS의 Control Plane의 로그를 CloudWatch로 전송

* cloudWatch
	* clusterLogging: Control Plane의 로그를 CloudWatch로 전송
		* enableTypes: 활성화 할 로그 타입
			* 타입: api, audit, authenticator, controllerManager, scheduler

### 구성 파일의 스키마 확인

전체 스키마 웹페이지: https://eksctl.io/usage/schema/
전체 스키마 확인 명령: `eksctl utils schema`
구성 파일 예제: https://github.com/weaveworks/eksctl/tree/main/examples

---

## 4. EKS 클러스터 생성

### 클러스터 구성 파일

> myeks.yaml
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: myeks
  region: ap-northeast-2
  version: "1.22"

# AZ
availabilityZones: ["ap-northeast-2a", "ap-northeast-2b",  "ap-northeast-2c"]

# IAM OIDC & Service Account
iam:
  withOIDC: true
  serviceAccounts:
    - metadata:
        name: aws-load-balancer-controller
        namespace: kube-system
      wellKnownPolicies:
        awsLoadBalancerController: true

# Managed Node Groups
managedNodeGroups:
  # On-Demand Instance
  - name: myng-1
    instanceType: t2.small
    minSize: 1
    desiredCapacity: 2
    maxSize: 3
    privateNetworking: true
    ssh:
      allow: true
      publicKeyPath: ./myeks-key.pub
    availabilityZones: ["ap-northeast-2a", "ap-northeast-2b"]
    iam:
      withAddonPolicies:
        autoScaler: true
        albIngress: true
        cloudWatch: true
        ebs: true
```

### SSH 키 생성

```
mkdir keypair
ssh-keygen -f keypair/myeks -N ''
```

### EKS 클러스터 생성

클러스터 생성
```
eksctl create cluster -f myeks.yaml
```
> 클러스터 생성 시간: 10 ~ 15분 소요
> 노드 그룹 생성 시간: 5 ~ 10분 소요

클러스터 확인
```
eksctl get cluster

NAME	REGION		EKSCTL CREATED
myeks	ap-northeast-2	True
```

노드 그룹 확인
```
eksctl get nodegroup --cluster myeks

CLUSTER	NODEGROUP	STATUS		CREATED			MIN SIZE	MAX SIZE	DESIRED CAPACITY	INSTANCE TYPE	IMAGE ID	ASG NAME
myeks	myng-1		CREATE_COMPLETE	2021-02-19T01:40:59Z	1		3		2			t2.small			eks-aabbdbf9-998d-56d0-8ee8-4e2f94bbc1cc
```

### 클러스터 구성 파일: 스팟 인스턴스를 사용하는 노드 그룹 추가

> myeks-add-ng.yaml
```yaml
+++

  # Spot Instance
  - name: myng-2
    instanceTypes: ["t2.small", "t3.small"]
    desiredCapacity: 1
    privateNetworking: true
    spot: true
    ssh:
      allow: true
      publicKeyPath: ./keypair/myeks.pub
    availabilityZones: ["ap-northeast-2b", "ap-northeast-2c"]
    iam:
      withAddonPolicies:
        autoScaler: true
        albIngress: true
        cloudWatch: true
        ebs: true
```

### 노드그룹 생성

```
eksctl create nodegroup -f myeks-add-ng.yaml --include myng-2 --exclude myng-1
```

```
eksctl get nodegroup --cluster myeks

CLUSTER	NODEGROUP	STATUS		CREATED			MIN SIZE	MAX SIZE	DESIRED CAPACITY	INSTANCE TYPE	IMAGE ID	ASG NAME
myeks	myng-1		CREATE_COMPLETE	2021-02-19T01:40:59Z	1		3		2			t2.small			eks-aabbdbf9-998d-56d0-8ee8-4e2f94bbc1cc
myeks	myng-2		CREATE_COMPLETE	2021-02-19T01:47:17Z	1		1		1			t2.small			eks-5ebbdbfc-71ea-1969-829b-2658b33440eb
```

### 클러스터 구성 파일: Fargate 프로파일 추가

> myeks-add-fg.yaml
```yaml
+++

# Fargate Profiles
fargateProfiles:
  - name: fg-1
    selectors:
    - namespace: dev
      labels:
        env: fargate
```

### Fargate 프로파일 생성

```
eksctl create fargateprofile -f myeks-add-fg.yaml
```

```
eksctl get fargateprofile --cluster myeks

NAME	SELECTOR_NAMESPACE	SELECTOR_LABELS	POD_EXECUTION_ROLE_ARN		SUBNETS			TAGS	STATUS
fg-1	dev			env=fargate	arn:aws:iam::341121849...		subnet-007c2a7189...	<none>	ACTIVE
```

### 클러스터 구성 파일: CloudWatch 로깅 추가

> myeks-add-log.yaml
```yaml
+++

# CloudWatch Logging
cloudWatch:
  clusterLogging:
    enableTypes: ["api"]
```

### 클러스터 로깅 업데이트

로깅 업데이트
```
eksctl utils update-cluster-logging -f myeks-add-log.yaml
```

로깅 업데이트
```
eksctl utils update-cluster-logging -f myeks-add-log.yaml --approve
```


### 스케일링 노드 그룹

myng-1 노드 그룹 확인
```
eksctl get nodegroup --cluster myeks --name myng-1

CLUSTER	NODEGROUP	... MIN SIZE	MAX SIZE	DESIRED CAPACITY	...
myeks		myng-1		... 1			3			2					...
```

노드 그룹 스케일 아웃
```
eksctl scale nodegroup --cluster myeks --name myng-1 --nodes 3
```

myng-1 노드 그룹 확인
```
eksctl get nodegroup --cluster myeks --name myng-1

CLUSTER	NODEGROUP	... MIN SIZE	MAX SIZE	DESIRED CAPACITY	...
myeks		myng-1		... 1			3			3					...
```

노드 그룹 스케일 인
```
eksctl scale nodegroup --cluster myeks --name myng-1 --nodes 2
```

myng-1 노드 그룹 확인
```
eksctl get nodegroup --cluster myeks --name myng-1

CLUSTER	NODEGROUP	... MIN SIZE	MAX SIZE	DESIRED CAPACITY	...
myeks		myng-1		... 1			3			2					...
```

### 생성된 클러스터 노드 확인

```
kubectl get nodes

NAME                              STATUS   ROLES    AGE   VERSION
ip-192-168-126-162.ec2.internal   Ready    <none>   21m   v1.22.9-eks-d1db3c
ip-192-168-140-120.ec2.internal   Ready    <none>   15m   v1.22.9-eks-d1db3c
ip-192-168-150-145.ec2.internal   Ready    <none>   21m   v1.22.9-eks-d1db3c
```
