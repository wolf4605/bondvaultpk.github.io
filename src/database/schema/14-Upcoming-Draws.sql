-- * Project Name: BONDVAULT PK

-- * Description: 

-- * Author: Wolf4605
-- * Email: mab4605@gmail.com

-- * Date: 2026-11-06 12:01:19

-- * Last Modified by:   Wolf4605
-- * Last Modified time: 2026-11-07 20:53:51

-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.
CREATE TABLE IF NOT EXISTS "upcoming_draws" (
    "draw_date" DATE NOT NULL,
    "denomination" INT NOT NULL CHECK (
        "denomination" IN (100, 200, 750, 1500, 25000, 40000)
    ),
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "location" TEXT,
    CONSTRAINT "pk_upcoming_draws" PRIMARY KEY ("draw_date", "denomination")
);
