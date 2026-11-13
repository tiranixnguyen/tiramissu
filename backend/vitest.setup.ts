// File này nằm ngoài `include` của tsconfig (Vitest tự nạp qua esbuild), mà
// tsconfig lại đặt `"types": []` -> editor không thấy `process`. Kéo kiểu Node
// vào riêng file này thay vì bật cho cả app.
/// <reference types="node" />
// Giống src/config/db.ts: `import "dotenv/config"` thiếu khai báo kiểu dưới
// resolver của project.
import dotenv from "dotenv";

dotenv.config();

// Test dùng user riêng, tách khỏi DEFAULT_USER_EMAIL thật — để chạy test trên
// cùng Postgres dev không bao giờ đụng tới (xoá/ghi đè) dữ liệu cá nhân thật.
// Phải set TRƯỚC khi bất kỳ module nào import `defaultUser.ts`, vì hằng số đó
// đọc process.env ngay lúc module được nạp. Vitest chạy setupFiles trước khi
// nạp file test, nên đặt ở đây là đúng chỗ (không thể đặt trong file .test.ts
// vì TypeScript bắt buộc `import` đứng trước mọi statement khác).
process.env.DEFAULT_USER_EMAIL = "sync-integration-test@vocab-app.local";

// Bật xác thực trong test và tự gắn token vào mọi fetch tới server test.
// Test xác thực muốn gửi request "trần" thì đặt header `X-Test-No-Auth`.
process.env.API_TOKEN = "test-token";
const realFetch = globalThis.fetch;
globalThis.fetch = (input, init) => {
  const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : {}));
  if (headers.has("x-test-no-auth")) {
    headers.delete("x-test-no-auth");
  } else if (!headers.has("authorization")) {
    headers.set("Authorization", `Bearer ${process.env.API_TOKEN}`);
  }
  return realFetch(input, { ...init, headers });
};
