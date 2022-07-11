# Vagrant 설치 및 사용법
[Vagrant 공식 사이트](https://www.vagrantup.com/)

작성날짜: 2018년 11월 30일
업데이트: 2022년 06월 14일

## 1. 패키지 관리자 및 Vagrant 패키지 설치

* Windows
https://chocolatey.org/install
	* Windows 7+ / Windows Server 2003+
	* PowerShell v2+
	* .NET Framework 4+
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

```
choco install vagrant
```

* macOS
https://brew.sh/index_ko
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

```
brew install vagrant
```

- Linux - Debian/Ubuntu
```
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
```

```
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
```

```
sudo apt-get update && sudo apt-get install vagrant
```

## 2. VirtualBox 다운로드 및 설치

* 설치 파일 및 패키지
https://www.virtualbox.org/wiki/Downloads

* Windows
```
choco install virtualbox virtualbox.extensionpack
```

* macOS
```
brew install virtualbox virtualbox-extension-pack
```

* Linux - Ubuntu
> https://www.virtualbox.org/wiki/Linux_Downloads

```
echo -e "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian bionic contrib" | sudo tee -a /etc/apt/sources.list
```

```
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
```

```
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
```

```
sudo apt-get update
```

```
sudo apt-get install virtualbox virtualbox-guest-utils virtualbox-ext-pack
```

## 3. Vagrant

### Box 이미지 다운로드
```
vagrant box add ubuntu/focal64
```

### Vagrant 파일
```
cd ~ 
mkdir kube
cd kube  
```

> 호스트 시스템의 사양에 따라 Master 및 Node 개수 및 리소스를 적절하게 할당
> Control Plane 최소 RAM 요구사항: 1500MB
> Node 최소 RAM 요구사항: 1024MB

### Vagrantfile 파일 작성
> Vagrantfile
```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  $vm_provider = "virtualbox"
  $box_image = "ubuntu/focal64"

  $vm_name_prefix = "kube"

  $number_of_control_planes = 1
  $number_of_nodes = 3

  $vm_subnet = "192.168.56"

  $vm_control_plane_cpus = 2
  $vm_control_plane_memory = 3072
  $vm_node_cpus = 2
  $vm_node_memory = 2560

  # Kubernetes Control Planes
  (1..$number_of_control_planes).each do |i|
    config.vm.define "#{$vm_name_prefix}-control#{i}" do |node|
      node.vm.box = $box_image
      node.vm.provider $vm_provider do |vm|
        vm.name = "#{$vm_name_prefix}-control#{i}"
        vm.cpus = $vm_control_plane_cpus
        vm.memory = $vm_control_plane_memory
      end
      node.vm.hostname = "#{$vm_name_prefix}-control#{i}"
      node.vm.network "private_network", ip: "#{$vm_subnet}.1#{i}", nic_type: "virtio"
    end
  end

  # Kubernetes Nodes
  (1..$number_of_nodes).each do |i|
    config.vm.define "#{$vm_name_prefix}-node#{i}" do |node|
      node.vm.box = $box_image
      node.vm.provider $vm_provider do |vm|
        vm.name = "#{$vm_name_prefix}-node#{i}"
        vm.cpus = $vm_node_cpus
        vm.memory = $vm_node_memory
      end
      node.vm.hostname = "#{$vm_name_prefix}-node#{i}"
      node.vm.network "private_network", ip: "#{$vm_subnet}.2#{i}", nic_type: "virtio"
    end
  end

  # Disable Synced Folder
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Enable SSH Password Authentication
  config.vm.provision "shell", inline: <<-SHELL
    sed -i 's/archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
    sed -i 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    systemctl restart ssh
  SHELL
end
```

| Control Plane      | IP               | CPU | Memory |
|--------------------|------------------|-----|--------|
| kube-control1 | 192.168.56.11/24 | 2   | 2560MB |

| Node               | IP               | CPU | Memory |
|--------------------|------------------|-----|--------|
| kube-node1         | 192.168.56.21/24 | 2   | 2560MB |
| kube-node2         | 192.168.56.22/24 | 2   | 2560MB |
| kube-node3         | 192.168.56.23/24 | 2   | 2560MB |

### VM 배포
```
vagrant up
```

### VM 상태확인
```
vagrant status
```

### VM 접속
```
vagrant ssh kube-control1
```

### VM 종료
```
vagrant halt
```

## 4. Vagrant 사용법

### 상태확인
```
vagrant status [VM]
```

### 시작
```
vagrant up [VM]
```

### 일시중지
```
vagrant suspend [VM]
```

### 재개
```
vagrant resume [VM]
```


### 재부팅
```
vagrant reload [VM]
```

### 중지
```
vagrant halt [VM]
```

### 삭제
```
vagrant destroy [VM]
```

### SSH 연결
```
vagrant ssh [VM]
```
멀티 VM인 경우 반드시 VM 이름을 명시
