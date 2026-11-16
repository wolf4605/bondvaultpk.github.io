-- * Project Name: BONDVAULT PK
-- * Description: SQL Schema for reports and interactive report_messages tables.
-- * Author: Wolf4605
-- * Email: mab4605@gmail.com
-- * Date: 2026-10-22 09:42:07
-- * Last Modified by: Wolf4605
-- * Last Modified time: 2026-11-16 14:00:00
-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.

CREATE TABLE IF NOT EXISTS "reports"(
    "id" UUID PRIMARY KEY DEFAULT UUIDV7(),
    "reported_by" UUID NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
    "subject" VARCHAR(200) NOT NULL,
    "category" VARCHAR(50) NOT NULL DEFAULT 'general',
    "content" TEXT NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'open' CHECK ("status" IN ('open', 'in_progress', 'closed', 'pending', 'resolved')),
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMPTZ,
    "closed_by" UUID REFERENCES "admins"("id") ON DELETE SET NULL,
    "resolved_at" TIMESTAMPTZ,
    "resolved_by" UUID REFERENCES "admins"("id") ON DELETE SET NULL,
    "response" TEXT
);

CREATE TABLE IF NOT EXISTS "report_messages"(
    "id" UUID PRIMARY KEY DEFAULT UUIDV7(),
    "report_id" UUID NOT NULL REFERENCES "reports"("id") ON DELETE CASCADE,
    "sender_id" UUID NOT NULL,
    "sender_type" VARCHAR(10) NOT NULL CHECK ("sender_type" IN ('user', 'admin')),
    "sender_name" VARCHAR(150) NOT NULL,
    "message" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_report_messages_report_id" ON "report_messages"("report_id", "created_at" ASC);
CREATE INDEX IF NOT EXISTS "idx_reports_user" ON "reports"("reported_by", "created_at" DESC);
