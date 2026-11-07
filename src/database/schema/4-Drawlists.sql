-- * Project Name: BONDVAULT PK
-- * Description: SQL SCHEMA FOR drawlists Table
-- * Author: Wolf4605
-- * Email: mab4605@gmail.com
-- * Date: 2026-10-22 09:40:26
-- * Last Modified by:   Wolf4605
-- * Last Modified time: 2026-11-07 20:44:36
-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.
CREATE TABLE IF NOT EXISTS "drawlists"(
    "draw_id" UUID PRIMARY KEY DEFAULT UUIDV7(),
    "draw_date" DATE NOT NULL,
    "denomination" INT NOT NULL CHECK ("denomination" IN (100, 200, 750, 1500, 25000, 40000)),
    CONSTRAINT "uq_drawlists_date_denomination" UNIQUE ("draw_date", "denomination")
);

CREATE TABLE IF NOT EXISTS "draw_winners"(
    "draw_id" UUID NOT NULL,
    "bond_number" VARCHAR DEFAULT NULL,
    "prize_position" SMALLINT NOT NULL CHECK ("prize_position" IN (1, 2, 3)),
    "prize_amount" INT NOT NULL CHECK ("prize_amount" > 0),
    CONSTRAINT "pk_draw_winners" PRIMARY KEY ("draw_id", "bond_number"),
    CONSTRAINT "fk_draw_winners_drawlists" FOREIGN KEY ("draw_id") REFERENCES "drawlists"("draw_id") ON DELETE CASCADE
);