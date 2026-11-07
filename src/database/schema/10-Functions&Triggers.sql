-- * Project Name: BONDVAULT PK
-- * Description: Functions that are to be created with in the database and handeled by the database.
-- * Author: Wolf4605
-- * Email: mab4605@gmail.com
-- * Date: 2026-10-22 10:09:35
-- * Last Modified by:   Wolf4605
-- * Last Modified time: 2026-10-22 16:00:13
-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.
CREATE OR REPLACE FUNCTION handle_contact_permanent_blacklist()
    RETURNS TRIGGER
    AS $$
BEGIN
    -- NULL duration indicates a permanent ban.
    IF NEW.duration IS NULL THEN
        -- Delete users matching the blacklisted email or contact.
        DELETE FROM "users"
        WHERE "email" = NEW.email
            OR "contact" = NEW.contact;
    END IF;
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cleanup_past_upcoming_draws()
    RETURNS INTEGER
    AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM "upcoming_draws"
    WHERE "draw_date" < (
        CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi'
    )::DATE;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$
LANGUAGE plpgsql;

-- Create the trigger only if it does not already exist.
DO $$
BEGIN
    IF NOT EXISTS(
        SELECT
            1
        FROM
            pg_trigger
        WHERE
            tgname = 'trg_blacklist_contact_ban'
            AND tgrelid = '"blacklist"'::REGCLASS
            AND NOT tgisinternal) THEN
    CREATE TRIGGER trg_blacklist_contact_ban
        AFTER INSERT OR UPDATE ON "blacklist"
        FOR EACH ROW
        EXECUTE FUNCTION handle_contact_permanent_blacklist( );
END IF;
END;
$$;
