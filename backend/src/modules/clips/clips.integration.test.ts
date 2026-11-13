import { describe, expect, it } from "vitest";
import { prisma } from "../../config/db";
import { call, useTestServer } from "../../testing/testServer";
import { orphanAudioWhere } from "../audio/audioService";
import { ensureDefaultUser } from "../common/defaultUser";

const server = useTestServer();
const api = (method: string, path: string, body?: unknown) =>
  call(server.baseUrl, method, path, body);

const m4a = (tail: string) =>
  Buffer.concat([Buffer.from([0, 0, 0, 0x20]), Buffer.from("ftypM4A "), Buffer.from(tail)]);

async function uploadAudio(tail = "clip") {
  const res = await fetch(`${server.baseUrl}/audio`, {
    method: "POST",
    headers: { "Content-Type": "audio/mp4" },
    body: new Uint8Array(m4a(tail)),
  });
  return (await res.json()).id as string;
}

const valid = (audioId: string, extra: object = {}) => ({
  audioId,
  sourceName: "bai1.mp3",
  startMs: 1000,
  endMs: 4500,
  transcript: "안녕하세요",
  ...extra,
});

describe("CRUD clip", () => {
  it("tạo → liệt kê → sửa → xoá", async () => {
    const audioId = await uploadAudio();
    const created = await api("POST", "/clips", valid(audioId, { translation: "Xin chào" }));
    expect(created.status).toBe(201);
    expect(created.json).toMatchObject({
      audioId,
      startMs: 1000,
      endMs: 4500,
      transcript: "안녕하세요",
      translation: "Xin chào",
      note: null,
      deckId: null,
      marked: false,
    });

    expect((await api("GET", "/clips")).json).toHaveLength(1);

    const patched = await api("PATCH", `/clips/${created.json.id}`, {
      endMs: 5000,
      marked: true,
      translation: null,
    });
    expect(patched.json).toMatchObject({
      startMs: 1000,
      endMs: 5000,
      marked: true,
      translation: null,
    });
    expect(patched.json.transcript).toBe("안녕하세요");

    expect((await api("DELETE", `/clips/${created.json.id}`)).status).toBe(204);
    expect((await api("GET", "/clips")).json).toEqual([]);
    expect((await api("DELETE", `/clips/${created.json.id}`)).status).toBe(404);
    expect((await api("PATCH", `/clips/${created.json.id}`, { marked: true })).status).toBe(404);
  });

  it("gắn vào bộ; xoá bộ thì clip còn, deckId về null", async () => {
    const audioId = await uploadAudio();
    const g = await api("POST", "/groups", { name: "G" });
    const d = await api("POST", "/decks", {
      groupId: g.json.id,
      name: "Bài",
      words: [{ back: "가다", front: "đi" }],
    });
    const c = await api("POST", "/clips", valid(audioId, { deckId: d.json.id }));
    expect(c.json.deckId).toBe(d.json.id);
    expect((await api("POST", "/clips", valid(audioId, { deckId: "khong-co" }))).status).toBe(400);

    const user = await ensureDefaultUser(prisma);
    await prisma.deck.delete({ where: { id: d.json.id } });
    expect(await prisma.clip.findFirst({ where: { userId: user.id } })).toMatchObject({
      deckId: null,
    });
  });
});

describe("kiểm tra đầu vào", () => {
  it("từ chối start ≥ end, > 60 s, transcript thiếu/quá dài, audio lạ", async () => {
    const audioId = await uploadAudio();
    const bad = async (extra: object) =>
      (await api("POST", "/clips", valid(audioId, extra))).status;
    expect(await bad({ startMs: 5000, endMs: 5000 })).toBe(400);
    expect(await bad({ startMs: 6000, endMs: 5000 })).toBe(400);
    expect(await bad({ startMs: -1 })).toBe(400);
    expect(await bad({ startMs: 0, endMs: 60_001 })).toBe(400);
    expect(await bad({ startMs: 0, endMs: 60_000 })).toBe(201);
    expect(await bad({ transcript: "   " })).toBe(400);
    expect(await bad({ transcript: "가".repeat(501) })).toBe(400);
    expect(await bad({ transcript: "가".repeat(500) })).toBe(201);
    expect(await bad({ audioId: "khong-co" })).toBe(400);
    expect(await bad({ startMs: 1.5 })).toBe(400);
    expect((await api("POST", "/clips", { transcript: "x" })).status).toBe(400);
  });

  it("PATCH kiểm tra lại khoảng thời gian trên giá trị gộp", async () => {
    const audioId = await uploadAudio();
    const c = await api("POST", "/clips", valid(audioId));
    expect((await api("PATCH", `/clips/${c.json.id}`, { startMs: 9000 })).status).toBe(400);
    expect((await api("PATCH", `/clips/${c.json.id}`, { endMs: 70_000 })).status).toBe(400);
    expect((await api("PATCH", `/clips/${c.json.id}`, { transcript: "" })).status).toBe(400);
    expect((await api("PATCH", `/clips/${c.json.id}`, {})).status).toBe(400);
  });

  it("không đụng được audio của user khác", async () => {
    const other = await prisma.user.create({
      data: { email: "other-test@vocab-app.local", passwordHash: "x" },
    });
    try {
      const a = await prisma.audio.create({
        data: {
          userId: other.id,
          sha256: "abc",
          mime: "audio/mp4",
          size: 1,
          bytes: new Uint8Array([1]),
        },
      });
      expect((await api("POST", "/clips", valid(a.id))).status).toBe(400);
    } finally {
      await prisma.user.delete({ where: { email: "other-test@vocab-app.local" } });
    }
  });
});

describe("tích hợp", () => {
  it("/content có clips", async () => {
    const audioId = await uploadAudio();
    await api("POST", "/clips", valid(audioId));
    const content = await api("GET", "/content");
    expect(content.json.clips).toHaveLength(1);
    expect(content.json.clips[0]).toMatchObject({ audioId, transcript: "안녕하세요" });
  });

  it("prune-audio không coi audio còn clip là mồ côi", async () => {
    const withClip = await uploadAudio("a");
    const orphan = await uploadAudio("b");
    await api("POST", "/clips", valid(withClip));
    const user = await ensureDefaultUser(prisma);
    const future = new Date(Date.now() + 86_400_000);
    const found = await prisma.audio.findMany({
      where: orphanAudioWhere(user.id, future),
      select: { id: true },
    });
    expect(found.map((a) => a.id)).toEqual([orphan]);
  });

  it("không xoá được audio còn clip trỏ tới (Restrict)", async () => {
    const audioId = await uploadAudio();
    await api("POST", "/clips", valid(audioId));
    await expect(prisma.audio.delete({ where: { id: audioId } })).rejects.toThrow();
  });
});
