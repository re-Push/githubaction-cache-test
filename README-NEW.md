# GitHub Actions에서 S3를 활용한 빌드 캐시 최적화

이 프로젝트는 GitHub Actions 워크플로우에서 AWS S3를 활용하여 빌드 캐시와 Docker 빌드 캐시를 구현하고 성능을 개선하는 방법을 보여주는 예제입니다.

## 📋 주요 기능

- ✅ Node.js 의존성(node_modules)을 S3에 캐시하여 빌드 시간 단축
- ✅ Docker 빌드 레이어를 S3에 캐시하여 도커 이미지 빌드 시간 단축
- ✅ 캐시 효과 측정 및 비교를 위한 자동화된 워크플로우
- ✅ AWS ECR(Elastic Container Registry)에 빌드된 이미지 배포

## 🔍 성능 테스트 결과

실제 워크플로우 실행에서 확인된 성능 향상:

### Node.js 빌드 캐시

| 항목 | 첫 번째 실행 (캐시 미스) | 두 번째 실행 (캐시 히트) |
|------|----------------------|---------------------|
| 캐시 상태 | "Cache miss, installing dependencies..." | "Cache hit, using cached node_modules" |
| 의존성 설치 시간 | 전체 설치 (약 1초) | 캐시 기반 설치 (약 0.7초) |
| 전체 작업 시간 | 약 14초 | 약 5초 |

### Docker 빌드 캐시

| 항목 | 첫 번째 실행 (캐시 미스) | 두 번째 실행 (캐시 히트) |
|------|----------------------|---------------------|
| 캐시 상태 | 전체 레이어 다시 빌드 | 대부분의 레이어 `CACHED` 표시 |
| Dockerfile 단계 | 모든 단계 실행 | 변경되지 않은 대부분의 단계 스킵 |
| `npm ci` 실행 상태 | 전체 실행 | `CACHED` (즉시 완료) |
| 전체 작업 시간 | 약 44초 | 약 15초 |

## 🛠️ 구성 방법

### 필수 조건

1. AWS 계정
2. S3 버킷 생성 완료
3. Amazon ECR 리포지토리 생성 완료
4. GitHub 저장소에 다음 시크릿 설정:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

### AWS 설정 정보

**S3 버킷 설정:**
- 버킷 이름: `s3-github-action-jaemin`
- 리전: `ap-northeast-3` (오사카)

**ECR 리포지토리:**
- 리포지토리: `repush/build-cache-test`
- 리전: `ap-northeast-3` (오사카)
- URI: `211125752707.dkr.ecr.ap-northeast-3.amazonaws.com/repush/build-cache-test`

## 📝 워크플로우 설명

GitHub Actions 워크플로우(`.github/workflows/docker-s3-cache.yml`)는 다음 두 가지 주요 작업으로 구성되어 있습니다:

### 1. Node.js 빌드 캐시 (S3)

```yaml
- name: Retrieve node_modules cache from S3
  uses: leroy-merlin-br/action-s3-cache@v1
  with:
    action: get
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ap-northeast-3
    bucket: s3-github-action-jaemin
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    artifacts: node_modules/**/*
```

### 2. Docker BuildX 캐시 (S3)

```yaml
- name: Build with S3 cache and push to ECR
  uses: docker/build-push-action@v6
  with:
    context: .
    push: true  # ECR에 이미지 푸시
    tags: |
      211125752707.dkr.ecr.ap-northeast-3.amazonaws.com/repush/build-cache-test:latest
      211125752707.dkr.ecr.ap-northeast-3.amazonaws.com/repush/build-cache-test:${{ env.IMAGE_TAG }}
    cache-from: type=s3,region=ap-northeast-3,bucket=s3-github-action-jaemin,name=docker-cache
    cache-to: type=s3,region=ap-northeast-3,bucket=s3-github-action-jaemin,name=docker-cache,mode=max
```

## 💡 S3 캐시 장점

1. **영구적인 캐시**: GitHub Actions의 기본 캐시는 7일 이후 삭제되지만, S3 캐시는 필요한 만큼 오래 보관 가능
2. **팀 간 공유**: 여러 개발자나 워크플로우 간에 캐시 공유 가능
3. **용량 제한 없음**: GitHub Actions 캐시 제한(무료: 500MB, 유료: 10GB)을 받지 않음
4. **안정성**: AWS S3의 높은 안정성과 가용성 활용
5. **비용 효율**: 빌드 시간 단축으로 CI/CD 비용 절감

## 🔒 필요한 IAM 권한

S3 캐시와 ECR 푸시를 사용하려면 다음 IAM 권한이 필요합니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::s3-github-action-jaemin",
        "arn:aws:s3:::s3-github-action-jaemin/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    }
  ]
}
```

## 📚 참고사항

- `BuildX`는 Docker의 확장 빌드 도구로, 다양한 캐시 백엔드(S3 포함)를 지원합니다.
- 첫 번째 실행 시 캐시가 없으므로 전체 빌드가 진행되며, 두 번째 실행부터 캐시 효과가 나타납니다.
- S3 스토리지 비용을 최적화하기 위해 필요에 따라 S3 버킷에 수명주기 정책을 설정할 수 있습니다.
- 워크플로우는 GitHub Actions 탭에서 수동으로 실행할 수도 있습니다.

## 📊 결론

S3를 활용한 빌드 캐싱은 GitHub Actions 워크플로우의 실행 시간을 크게 단축하고, 특히 규모가 큰 프로젝트에서 더 큰 효과를 발휘합니다. 이 접근 방식은 Node.js 애플리케이션 빌드와 Docker 이미지 생성 모두에서 효과적으로 작동하며, CI/CD 파이프라인의 효율성을 크게 향상시킵니다. 