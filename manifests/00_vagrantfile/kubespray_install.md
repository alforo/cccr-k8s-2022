# Kubespray를 이용한 Production Ready Kubernetes 클러스터 배포

[Kubespray GitHub 저장소](https://github.com/kubernetes-sigs/kubespray)

작성날짜: 2018년 11월 30일
업데이트: 2022년 06월 14일

> kubespray는 Kubernetes를 프로덕션 온프레미스에 설치할 수 있는 배포방법 (kubeadm 사용)

## 0. On-Premise 노드 구성

OS: Ubuntu 20.04 LTS(Focal)

| Control Plane      | IP               | CPU | Memory |
|--------------------|------------------|-----|--------|
| kube-control1 | 192.168.56.11/24 | 2   | 2560MB |

| Node               | IP               | CPU | Memory |
|--------------------|------------------|-----|--------|
| kube-node1         | 192.168.56.21/24 | 2   | 2560MB |
| kube-node2         | 192.168.56.22/24 | 2   | 2560MB |
| kube-node3         | 192.168.56.23/24 | 2   | 2560MB |

## 1. Requirements

* Ansible 2.11+, python-netaddr
* Jinja 2.11+
* 인터넷 연결(도커 이미지 가져오기)
* IPv4 포워딩
* SSH 키 복사
* 배포 중 문제가 발생하지 않도록 방화벽 비활성
* 적절한 권한 상승(non-root 사용자인 경우, passwordless sudo 설정)

* Control Plane
	* Memory: 1500MB
* Node
	* Memory: 1024MB

### 1) Control Plane
* SSH 키 복사
```
ssh-keygen -f ~/.ssh/id_rsa -N ''
ssh-copy-id vagrant@192.168.56.11
ssh-copy-id vagrant@192.168.56.21
ssh-copy-id vagrant@192.168.56.22
ssh-copy-id vagrant@192.168.56.23
```

> vagrant 이미지의 기본 사용자 vagrant, 기본 패스워드 vagrant 

* python3, pip, git 설치
```
sudo apt update  
sudo apt install -y python3 python3-pip git
```

## 2. Kubespray 배포

* 홈 디렉토리 이동
```
cd ~
```

* kubespray Git 저장소 클론
```
git clone --single-branch --branch release-2.19 https://github.com/kubernetes-sigs/kubespray.git  
```

* 디렉토리 변경
```
cd kubespray
```

* requirements.txt 파일에서 의존성 확인 및 설치
```
sudo pip3 install -r requirements.txt  
```

* 인벤토리 준비
```
cp -rfp inventory/sample inventory/mycluster
```

* 인벤토리 수정
```
vi inventory/mycluster/inventory.ini
```

```ini
[all]  
kube-control1	ansible_host=192.168.56.11 ip=192.168.56.11
kube-node1	ansible_host=192.168.56.21 ip=192.168.56.21
kube-node2	ansible_host=192.168.56.22 ip=192.168.56.22
kube-node3	ansible_host=192.168.56.23 ip=192.168.56.23

[kube_control_plane]  
kube-control1 

[etcd]  
kube-control1  

[kube_node]  
kube-node1  
kube-node2
kube-node3  

[calico_rr]  

[k8s_cluster:children]  
kube_control_plane  
kube_node  
calico_rr
```

* 파라미터 확인 및 변경
```
vi inventory/mycluster/group_vars/k8s_cluster/addons.yml
```

```yaml
metrics_server_enabled: true
ingress_nginx_enabled: true
metallb_enabled: true
metallb_ip_range:
  - "192.168.56.200-192.168.56.209"
metallb_protocol: "layer2"
```

```
vi inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
```

```
kube_proxy_strict_arp: true
container_manager: docker
```

* Ansible 통신 가능 확인
```
ansible all -i inventory/mycluster/inventory.ini -m ping

kube-controlplane1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
kube-node1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
kube-node3 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
kube-node2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

* (옵션) apt 캐시 업데이트 (모든 노드)
```
ansible all -i inventory/mycluster/inventory.ini -m apt -a 'update_cache=yes' --become

kube-controlplane1 | CHANGED => {
    "cache_update_time": 1584068822,
    "cache_updated": true,
    "changed": true
}
kube-node1 | CHANGED => {
    "cache_update_time": 1584068827,
    "cache_updated": true,
    "changed": true
}
kube-node3 | CHANGED => {
    "cache_update_time": 1584068826,
    "cache_updated": true,
    "changed": true
}
kube-node2 | CHANGED => {
    "cache_update_time": 1584068826,
    "cache_updated": true,
    "changed": true
}
```

* (옵션) apt 업데이트 시 오류가 난다면 해당 VM로 이동해서 아래와 같이 조치
```
sudo rm -rf /var/lib/apt/lists/*
sudo apt update --fix-missing
sudo apt update
```

* 플레이북 실행
```
ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -e kube_version=v1.22.X --become
```

> 호스트 시스템 사양, VM 개수, VM 리소스 및 네트워크 성능에 따라 10~30분 소요

* 자격증명 가져오기
```
mkdir ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

* kubectl 명령 자동완성
```
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl
exec bash
```

* Kubernetes 클러스터 확인
```
kubectl get nodes
kubectl cluster-info
```

