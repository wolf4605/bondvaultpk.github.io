-- * Project Name: BONDVAULT PK
-- * Description: SQL Schema for users Table.
-- * Author: Wolf4605
-- * Email: mab4605@gmail.com
-- * Date: 2026-10-22 09:35:59
-- * Last Modified by:   Wolf4605
-- * Last Modified time: 2026-11-05 19:25:17
-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.
CREATE TABLE IF NOT EXISTS "users"(
    "id" UUID PRIMARY KEY DEFAULT UUIDV7(),
    "username" VARCHAR(50) NOT NULL UNIQUE,
    "email" VARCHAR(254) NOT NULL UNIQUE,
    "password_hash" VARCHAR(255) NOT NULL,
    "first_name" VARCHAR(100),
    "last_name" VARCHAR(100),
    "city" VARCHAR(200) NOT NULL,
    "address" TEXT NOT NULL,
    "contact" VARCHAR(20) NOT NULL UNIQUE,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_verified" BOOLEAN NOT NULL DEFAULT FALSE,
    "verified_by" UUID REFERENCES "admins"("id") ON DELETE SET NULL,
    "last_login" TIMESTAMPTZ DEFAULT NULL
);

