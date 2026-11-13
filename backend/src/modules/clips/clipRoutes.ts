import { Router } from "express";
import { prisma } from "../../config/db";
import { handle } from "../common/handle";
import { createClip, deleteClip, listClips, updateClip } from "./clipService";

/** Clip nghe cắt từ file âm thanh (Mac tạo/sửa; Mac + iPhone luyện). */
export const clipRouter = Router();

const bodyOf = (body: unknown) =>
  body && typeof body === "object" ? (body as Record<string, unknown>) : {};

clipRouter.get(
  "/clips",
  handle(async (_req, res, userId) => {
    res.json(await listClips(prisma, userId));
  }),
);

clipRouter.post(
  "/clips",
  handle(async (req, res, userId) => {
    res.status(201).json(await createClip(prisma, userId, bodyOf(req.body)));
  }),
);

clipRouter.patch(
  "/clips/:id",
  handle(async (req, res, userId) => {
    res.json(await updateClip(prisma, userId, String(req.params.id), bodyOf(req.body)));
  }),
);

clipRouter.delete(
  "/clips/:id",
  handle(async (req, res, userId) => {
    await deleteClip(prisma, userId, String(req.params.id));
    res.status(204).end();
  }),
);
