# 프로젝트 - Helm 패키지를 이용한 고가용성의 Wordpress CMS 배포

## 1. 구성 요구사항

- 네임스페이스: wordpress

- 웹(Wordpress)
  - 계정 정보
    - 사용자 계정: 선택
    - 사용자 패스워드: 선택
    - 사용자 이메일: 선택
    - 계정 이름: 본인 이름
    - 계정 성: 본인 성
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
  - 사용자: 선택
  - 사용자 패스워드: 선택
  - 데이터베이스: cccr_wordpress
  - 스토리지: 동적 프로비저닝
    - 용량: 1Gi
    - 접근 모드: RWO

- 인증 정보 공유(Memcached): 활성
  - 사용자: 선택
  - 사용자 패스워드: 선택

## 2. Helm을 이용한 Wordpress CMS 배포

파라미터 작성

`wp-values.yaml`
```yml
<Paste of Your Code>
```

Helm 릴리즈 배포
```bash
<Paste of Your Command>
```
