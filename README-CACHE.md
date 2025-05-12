# GitHub Actions S3 캐시 가이드

이 프로젝트는 GitHub Actions에서 AWS S3를 사용하여 빌드 캐시와 Docker BuildX 캐시를 구성하는 방법을 보여주는 예제입니다.

## 기능

- Node.js 빌드 캐시를 S3에 저장
- Docker BuildX 캐시를 S3에 저장
- 캐시 효과 측정 및 비교
- 빌드된 이미지를 Amazon ECR에 푸시

## 필수 조건

1. AWS 계정
2. S3 버킷 생성 완료
3. Amazon ECR 리포지토리 생성 완료
4. GitHub 저장소에 다음 시크릿 설정:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## 설정 정보

S3 버킷 설정:
- 버킷 이름: `s3-github-action-jaemin`
- 리전: `ap-northeast-3` (오사카)

ECR 리포지토리:
- 리포지토리: `repush/build-cache-test`
- 리전: `ap-northeast-3` (오사카)
- URI: `211125752707.dkr.ecr.ap-northeast-3.amazonaws.com/repush/build-cache-test`

## 워크플로우 설명

이 저장소는 다음과 같은 캐시 및 배포 방식을 사용합니다:

### 1. 일반 빌드 캐시 (Node.js)

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
```

### 2. Docker BuildX 캐시 및 ECR 푸시

```yaml
# ECR 로그인
- name: Login to Amazon ECR
  id: login-ecr
  uses: aws-actions/amazon-ecr-login@v2

# 이미지 태그 생성
- name: Set image tag
  run: |
    echo "IMAGE_TAG=${GITHUB_SHA::8}" >> $GITHUB_ENV

# S3 캐시를 사용한 빌드 및 ECR 푸시
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

## 캐시 효과 측정

워크플로우는 각 빌드 단계의 실행 시간을 측정하고 비교합니다:

1. 첫 번째 실행: 캐시 없이 빌드하여 ECR에 푸시
2. 두 번째 실행: S3에서 캐시를 사용하여 빌드하고 ECR에 푸시

결과는 워크플로우 로그에서 확인할 수 있습니다.

## IAM 권한 설정

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

## 워크플로우 수동 실행

GitHub 저장소의 Actions 탭에서 "Docker Build with S3 Cache" 워크플로우를 수동으로 실행할 수 있습니다.

## 참고사항

- S3에 저장된 캐시는 GitHub Actions의 기본 7일 제한을 받지 않습니다.
- 필요에 따라 AWS S3 수명주기 정책을 설정하여 오래된 캐시를 자동으로 삭제할 수 있습니다.
- Docker BuildX의 S3 캐시 기능은 공식적으로는 아직 "실험적" 기능으로 분류되지만, 실제로는 많은 조직에서 안정적으로 사용 중입니다.
- ECR에 푸시되는 이미지에는 다음과 같은 태그가 지정됩니다:
  - `latest`: 가장 최신 빌드
  - `{커밋해시 앞 8자리}`: 특정 커밋에 대한 빌드
  - `cached-{커밋해시 앞 8자리}`: 캐시를 사용한 두 번째 빌드 