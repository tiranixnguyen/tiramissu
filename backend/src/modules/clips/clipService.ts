import type { PrismaClient } from "../../../prisma/generated/prisma/client";
import { HttpError } from "../common/httpError";
import { missingAudioIds } from "../audio/audioService";

export const MAX_CLIP_MS = 60_000;
export const MAX_TRANSCRIPT = 500;
const MAX_TEXT = 500;
const MAX_SOURCE_NAME = 200;

export interface ClipDto {
  id: string;
  audioId: string;
  sourceName: string;
  startMs: number;
  endMs: number;
  transcript: string;
  translation: string | null;
  note: string | null;
  deckId: string | null;
  marked: boolean;
  createdAt: Date;
}

export const clipSelect = {
  id: true,
  audioId: true,
  sourceName: true,
  startMs: true,
  endMs: true,
  transcript: true,
  translation: true,
  note: true,
  deckId: true,
  marked: true,
  createdAt: true,
} as const;

/** Chữ thuần, bỏ khoảng trắng hai đầu; rỗng → `null`. `undefined` = không hợp lệ. */
function optionalText(value: unknown): string | null | undefined {
  if (value === null) return null;
  if (typeof value !== "string") return undefined;
  const text = value.replace(/\r\n?/g, "\n").trim();
  if (text.length > MAX_TEXT) return undefined;
  return text || null;
}

const isInt = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v);

/** Bản ghi đã kiểm tra, sẵn sàng ghi DB. */
interface ClipFields {
  audioId: string;
  sourceName: string;
  startMs: number;
  endMs: number;
  transcript: string;
  translation: string | null;
  note: string | null;
  deckId: string | null;
  marked: boolean;
}

function checkRange(startMs: number, endMs: number) {
  if (startMs < 0 || endMs <= startMs) {
    throw new HttpError(400, "Điểm bắt đầu phải nhỏ hơn điểm kết thúc (ms, ≥ 0).");
  }
  if (endMs - startMs > MAX_CLIP_MS) {
    throw new HttpError(400, `Clip dài tối đa ${MAX_CLIP_MS / 1000} giây.`);
  }
}

function parseTranscript(value: unknown): string {
  const text = typeof value === "string" ? value.replace(/\r\n?/g, "\n").trim() : "";
  if (!text || text.length > MAX_TRANSCRIPT) {
    throw new HttpError(400, `Câu Hàn (transcript) bắt buộc, tối đa ${MAX_TRANSCRIPT} ký tự.`);
  }
  return text;
}

function parseTextField(value: unknown, label: string): string | null {
  const text = optionalText(value);
  if (text === undefined)
    throw new HttpError(400, `${label} phải là chữ, tối đa ${MAX_TEXT} ký tự.`);
  return text;
}

async function assertDeck(prisma: PrismaClient, userId: string, deckId: string | null) {
  if (deckId === null) return;
  const deck = await prisma.deck.findFirst({ where: { id: deckId, userId }, select: { id: true } });
  if (!deck) throw new HttpError(400, "Bộ (deckId) không tồn tại.");
}

async function assertAudio(prisma: PrismaClient, userId: string, audioId: string) {
  if ((await missingAudioIds(prisma, userId, [audioId])).length > 0) {
    throw new HttpError(400, "File nghe (audioId) không tồn tại.");
  }
}

export async function listClips(prisma: PrismaClient, userId: string): Promise<ClipDto[]> {
  return prisma.clip.findMany({
    where: { userId },
    select: clipSelect,
    orderBy: { createdAt: "asc" },
  });
}

export async function createClip(
  prisma: PrismaClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<ClipDto> {
  if (typeof body.audioId !== "string" || !body.audioId) {
    throw new HttpError(400, "Thiếu audioId.");
  }
  if (!isInt(body.startMs) || !isInt(body.endMs)) {
    throw new HttpError(400, "startMs và endMs phải là số nguyên (ms).");
  }
  checkRange(body.startMs, body.endMs);
  const sourceName =
    typeof body.sourceName === "string" ? body.sourceName.trim().slice(0, MAX_SOURCE_NAME) : "";
  const fields: ClipFields = {
    audioId: body.audioId,
    sourceName,
    startMs: body.startMs,
    endMs: body.endMs,
    transcript: parseTranscript(body.transcript),
    translation: parseTextField(body.translation ?? null, "Nghĩa"),
    note: parseTextField(body.note ?? null, "Ghi chú"),
    deckId: body.deckId === undefined || body.deckId === null ? null : String(body.deckId),
    marked: body.marked === true,
  };
  await assertAudio(prisma, userId, fields.audioId);
  await assertDeck(prisma, userId, fields.deckId);
  return prisma.clip.create({ data: { userId, ...fields }, select: clipSelect });
}

/** Thiếu trường = giữ; `translation`/`note`/`deckId` = `null` để xoá. Audio không đổi được. */
export async function updateClip(
  prisma: PrismaClient,
  userId: string,
  id: string,
  body: Record<string, unknown>,
): Promise<ClipDto> {
  const current = await prisma.clip.findFirst({ where: { id, userId }, select: clipSelect });
  if (!current) throw new HttpError(404, "Không tìm thấy clip.");

  const patch: Partial<ClipFields> = {};
  if (body.startMs !== undefined || body.endMs !== undefined) {
    const startMs = body.startMs ?? current.startMs;
    const endMs = body.endMs ?? current.endMs;
    if (!isInt(startMs) || !isInt(endMs)) {
      throw new HttpError(400, "startMs và endMs phải là số nguyên (ms).");
    }
    checkRange(startMs, endMs);
    patch.startMs = startMs;
    patch.endMs = endMs;
  }
  if (body.transcript !== undefined) patch.transcript = parseTranscript(body.transcript);
  if (body.translation !== undefined) patch.translation = parseTextField(body.translation, "Nghĩa");
  if (body.note !== undefined) patch.note = parseTextField(body.note, "Ghi chú");
  if (body.sourceName !== undefined) {
    if (typeof body.sourceName !== "string") throw new HttpError(400, "sourceName phải là chữ.");
    patch.sourceName = body.sourceName.trim().slice(0, MAX_SOURCE_NAME);
  }
  if (body.marked !== undefined) {
    if (typeof body.marked !== "boolean") throw new HttpError(400, "marked phải là true/false.");
    patch.marked = body.marked;
  }
  if (body.deckId !== undefined) {
    if (body.deckId !== null && typeof body.deckId !== "string") {
      throw new HttpError(400, "deckId phải là chữ hoặc null.");
    }
    patch.deckId = body.deckId;
    await assertDeck(prisma, userId, patch.deckId);
  }
  if (Object.keys(patch).length === 0) {
    throw new HttpError(
      400,
      "Không có gì để sửa (startMs, endMs, transcript, translation, note, deckId, marked, sourceName).",
    );
  }
  return prisma.clip.update({ where: { id }, data: patch, select: clipSelect });
}

export async function deleteClip(prisma: PrismaClient, userId: string, id: string): Promise<void> {
  const { count } = await prisma.clip.deleteMany({ where: { id, userId } });
  if (count === 0) throw new HttpError(404, "Không tìm thấy clip.");
}
