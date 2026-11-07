-- * Project Name: BONDVAULT PK
-- * Description: Automated Tasks that are to be performed within the database.
-- * Author: Wolf4605
-- * Email: mab4605@gmail.com
-- * Date: 2026-10-22 10:02:36
-- * Last Modified by:   Wolf4605
-- * Last Modified time: 2026-10-22 15:58:24
-- * License: MIT
-- * Copyright© BondVault PK. All rights reserved.
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove the existing job with this name, if present.
SELECT
    cron.unschedule(jobid)
FROM
    cron.job
WHERE
    jobname = 'cleanup_expired_blacklist';

-- Schedule the job exactly once.
SELECT
    cron.schedule('cleanup_expired_blacklist', '0 * * * *', $$ DELETE FROM "blacklist"
        WHERE "duration" IS NOT NULL
            AND "duration" <= NOW();

$$);

SELECT
    cron.unschedule(jobid)
FROM
    cron.job
WHERE
    jobname = 'cleanup_past_upcoming_draws';

SELECT
    cron.schedule(
        'cleanup_past_upcoming_draws',
        '0 * * * *',
        $$ DELETE FROM "upcoming_draws"
           WHERE "draw_date" < (
               CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi'
           )::date;
        $$
    );
