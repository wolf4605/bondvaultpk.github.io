-- * Project Name: BONDVAULT PK
-- * Description: SQL Schema for blacklist table
-- * Author: Wolf4605
-- * Email: mab4605@gmail.com
-- * Date: 2026-10-22 09:43:46
-- * Last Modified by:   Wolf4605
-- * Last Modified time: 2026-11-07 16:25:24
-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.
CREATE TABLE IF NOT EXISTS "blacklist"(
    "id" UUID PRIMARY KEY DEFAULT UUIDV7(),
    "email" VARCHAR(255) NOT NULL,
    "contact" VARCHAR(50) NOT NULL,
    "duration" TIMESTAMPTZ,
    "reason" TEXT,
    "created_at" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

