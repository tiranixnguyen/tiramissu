// prisma.config.ts
import "dotenv/config";
import { defineConfig, env } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    // Migration cần kết nối direct (không qua PgBouncer): trên Neon dùng DATABASE_URL_UNPOOLED.
    // Không có biến này (dev local) thì dùng DATABASE_URL như cũ. App lúc chạy (`db.ts`) vẫn dùng
    // DATABASE_URL — chuỗi pooled là tốt cho server.
    url: process.env.DATABASE_URL_UNPOOLED || env("DATABASE_URL"),
  },
});
