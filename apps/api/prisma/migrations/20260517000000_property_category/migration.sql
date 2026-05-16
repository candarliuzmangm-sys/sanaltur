-- CreateEnum
CREATE TYPE "PropertyCategory" AS ENUM ('APARTMENT', 'VILLA', 'OFFICE', 'STORE', 'SHOP', 'OTHER');

-- AlterTable
ALTER TABLE "Property"
  ADD COLUMN "category" "PropertyCategory" NOT NULL DEFAULT 'APARTMENT',
  ADD COLUMN "floorCount" INTEGER,
  ADD COLUMN "roomCounts" JSONB;
