# 멀티 스테이지 빌드 예제 (Node.js 애플리케이션)
FROM node:18-alpine AS deps

WORKDIR /app

# 패키지 파일 복사 (캐시 최적화)
COPY package.json package-lock.json* ./
RUN npm ci

# 빌드 단계
FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# 애플리케이션 빌드
RUN echo "Building application..." && \
    mkdir -p dist && \
    echo 'console.log("Hello from Docker cached build!");' > dist/index.js && \
    echo "Build completed!"

# 프로덕션 단계
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV production

# 필요한 파일만 복사
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

# 사용자 권한 설정 (보안)
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 appuser
USER appuser

EXPOSE 3000

CMD ["node", "dist/index.js"] 