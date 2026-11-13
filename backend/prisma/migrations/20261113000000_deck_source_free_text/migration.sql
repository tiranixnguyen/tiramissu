-- Đổi Deck.source từ enum sang chuỗi tự do, giữ dữ liệu theo nhãn cũ.
ALTER TABLE "Deck" ALTER COLUMN "source" TYPE TEXT USING (
  CASE "source"::text
    WHEN 'snu3a' THEN 'SNU 3A'
    WHEN 'snu3b' THEN 'SNU 3B'
    WHEN 'snu4a' THEN 'SNU 4A'
    WHEN 'snu4b' THEN 'SNU 4B'
    WHEN 'thth3' THEN 'THTH 3'
    WHEN 'thth4' THEN 'THTH 4'
  END
);

-- DropEnum
DROP TYPE "DeckSource";
