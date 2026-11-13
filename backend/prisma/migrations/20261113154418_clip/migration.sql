-- CreateTable
CREATE TABLE "Clip" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "audioId" TEXT NOT NULL,
    "sourceName" TEXT NOT NULL,
    "startMs" INTEGER NOT NULL,
    "endMs" INTEGER NOT NULL,
    "transcript" TEXT NOT NULL,
    "translation" TEXT,
    "note" TEXT,
    "deckId" TEXT,
    "marked" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Clip_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Clip_userId_createdAt_idx" ON "Clip"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "Clip" ADD CONSTRAINT "Clip_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Clip" ADD CONSTRAINT "Clip_audioId_fkey" FOREIGN KEY ("audioId") REFERENCES "Audio"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Clip" ADD CONSTRAINT "Clip_deckId_fkey" FOREIGN KEY ("deckId") REFERENCES "Deck"("id") ON DELETE SET NULL ON UPDATE CASCADE;
