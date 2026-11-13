# syntax=docker/dockerfile:1
# Build nhiều tầng: tầng build biên dịch TypeScript, tầng chạy chỉ giữ những gì cần.
FROM node:22-slim AS build
WORKDIR /app
# openssl: Prisma cần khi generate/chạy trên bản slim.
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN npm ci
COPY prisma ./prisma
COPY prisma.config.ts tsconfig.json ./
COPY src ./src
# `prisma generate` không kết nối DB nhưng prisma.config.ts đọc DATABASE_URL.
RUN DATABASE_URL="postgresql://build:build@localhost:5432/build" npx prisma generate \
 && npx tsc

FROM node:22-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
# Giữ nguyên node_modules đầy đủ: `prisma migrate deploy` lúc khởi động cần Prisma CLI.
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/prisma.config.ts ./
USER node
# Lắng nghe $PORT (Render đặt); mặc định 3000.
EXPOSE 3000
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/src/index.js"]
