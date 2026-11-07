-- * Project Name: BONDVAULT PK
-- * Description: Indexes of the tables for faster look ups.
-- * Author: Wolf4605
-- * Email: mab4605@gmail.com
-- * Date: 2026-10-22 09:42:40
-- * Last Modified by:   Wolf4605
-- * Last Modified time: 2026-11-02 10:31:17
-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.
CREATE INDEX IF NOT EXISTS idx_users_verified_by ON "users"("verified_by")
WHERE
    "verified_by" IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bondlists_user_id ON "bondlists"("user_id");

CREATE INDEX IF NOT EXISTS idx_bonds_number ON "bonds"("bond_number");

CREATE INDEX IF NOT EXISTS idx_draw_winners_bond_search ON "draw_winners"("bond_number", "draw_id");

CREATE INDEX IF NOT EXISTS idx_market_posted_by ON "market"("posted_by");

CREATE INDEX IF NOT EXISTS idx_reports_reported_by ON "reports"("reported_by");

CREATE INDEX IF NOT EXISTS idx_reports_resolved_by ON "reports"("resolved_by")
WHERE
    "resolved_by" IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_blacklist_lookup ON "blacklist"("email", "contact");

