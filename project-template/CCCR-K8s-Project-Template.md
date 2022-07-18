# 프로젝트 - Helm 패키지를 이용한 고가용성의 Wordpress CMS 배포

## 1. 구성 요구사항

- 네임스페이스: wordpress

- 웹(Wordpress)
  - 계정 정보
    - 사용자 계정: cskim
    - 사용자 패스워드: cskim1234
    - 사용자 이메일: cskim@deepnoid.com
    - 계정 이름: Changsoo
    - 계정 성: Kim
    - 블로그 이름: CCCR K8s Project
  - 복제본 수: 2
  - 리소스 요청:
    - CPU: 300m
    - 메모리: 300Mi
  - 모든 프로브 활성
  - 서비스 종류: NodePort
  - 인그레스: 활성
    - 호스트 이름: cccr.example.com
  - 스토리지: 동적 프로비저닝
    - 용량: 1Gi
    - 접근 모드: RWX

- 데이터베이스(Mariadb)
  - 읽기 복제본 구성
  - 사용자: cskim
  - 사용자 패스워드: cskim1234
  - 데이터베이스: cccr_wordpress
  - 스토리지: 동적 프로비저닝
    - 용량: 1Gi
    - 접근 모드: RWO

- 인증 정보 공유(Memcached): 활성
  - 사용자: cskim
  - 사용자 패스워드: cskim1234

## 2. Helm을 이용한 Wordpress CMS 배포

파라미터 작성

`wp-values.yaml`
```yml
wordpressUsername: cskim
wordpressPassword: "cskim1234"
wordpressEmail: cskim@deepnoid.com
wordpressFirstName: Changsoo
wordpressLastName: Kim
wordpressBlogName: CCCR K8s Project

replicaCount: 2
resources:
  requests:
    cpu: 300m
    memory: 300Mi

startupProbe:
  enabled: true

service:
  type: NodePort

ingress:
  enabled: true
  hostname: cccr.example.com

persistence:
  accessModes:
    - ReadWriteMany
  size: 1Gi

mariadb:
  architecture: replication
  auth:
    database: cccr_wordpress
    username: cskim
    password: "cskim1234"
  primary:
    persistence:
      size: 1Gi
  secondary:
    persistence:
      size: 1Gi

memcached:
  enabled: true
  auth:
    enabled: true
    username: "cskim"
    password: "cskim1234"
```

Helm 릴리즈 배포
```bash
helm install wordpress bitnami/wordpress -f wp-values.yaml -n wordpress
```
