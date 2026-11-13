import { describe, expect, it } from "vitest";
import { useTestServer } from "../../testing/testServer";
import { assertAuthConfigured, tokensMatch } from "./auth";

const server = useTestServer();
const get = (path: string, headers: Record<string, string> = {}) =>
  fetch(`${server.baseUrl}${path}`, { headers: { "X-Test-No-Auth": "1", ...headers } });

describe("xác thực bằng token", () => {
  it("thiếu token → 401 JSON", async () => {
    const res = await get("/content");
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: "Thiếu hoặc sai mã truy cập." });
  });

  it("sai token → 401", async () => {
    expect((await get("/content", { Authorization: "Bearer sai" })).status).toBe(401);
    expect((await get("/content", { Authorization: "test-token" })).status).toBe(401);
  });

  it("đúng token → 200", async () => {
    expect((await get("/content", { Authorization: "Bearer test-token" })).status).toBe(200);
  });

  it("/health không cần token", async () => {
    expect((await get("/health")).status).toBe(200);
  });
});

describe("cấu hình", () => {
  it("tokensMatch so đúng cả khi lệch độ dài", () => {
    expect(tokensMatch("abc", "abc")).toBe(true);
    expect(tokensMatch("abc", "abcd")).toBe(false);
    expect(tokensMatch("abd", "abc")).toBe(false);
  });

  it("production thiếu API_TOKEN → ném lỗi; dev thì cho qua", () => {
    expect(() => assertAuthConfigured({ NODE_ENV: "production" })).toThrow();
    expect(() => assertAuthConfigured({ NODE_ENV: "production", API_TOKEN: "x" })).not.toThrow();
    expect(() => assertAuthConfigured({})).not.toThrow();
  });
});
