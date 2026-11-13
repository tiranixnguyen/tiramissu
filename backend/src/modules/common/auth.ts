import { timingSafeEqual } from "node:crypto";
import type { NextFunction, Request, Response } from "express";

/** Token đúng, đọc mỗi request để test đổi được qua `process.env`. */
function expectedToken(): string {
  return process.env.API_TOKEN ?? "";
}

/** So hai chuỗi trong thời gian không phụ thuộc nội dung (độ dài lệch → sai). */
export function tokensMatch(given: string, expected: string): boolean {
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * Yêu cầu `Authorization: Bearer <API_TOKEN>`. `API_TOKEN` rỗng (chỉ cho phép
 * ở dev — xem `assertAuthConfigured`) → bỏ qua kiểm tra.
 */
export function requireToken(req: Request, res: Response, next: NextFunction) {
  const expected = expectedToken();
  if (!expected) return next();
  const header = req.header("authorization") ?? "";
  const match = /^Bearer (.+)$/i.exec(header);
  if (match && tokensMatch(match[1] ?? "", expected)) return next();
  res.status(401).json({ error: "Thiếu hoặc sai mã truy cập." });
}

/** Gọi lúc khởi động: production mà thiếu `API_TOKEN` thì từ chối chạy. */
export function assertAuthConfigured(env: NodeJS.ProcessEnv = process.env): void {
  if (env.API_TOKEN) return;
  if (env.NODE_ENV === "production") {
    throw new Error("Thiếu API_TOKEN — từ chối khởi động ở môi trường production.");
  }
  console.warn("Cảnh báo: API_TOKEN rỗng — mọi request đều được chấp nhận (chỉ dùng khi dev).");
}
