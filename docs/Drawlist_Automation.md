# Automated draw-list processing

The backend runs the draw-list workflow once after startup and then daily at
10:00 PM Pakistan Standard Time (UTC+05:00). Draw results use the configured
source; the upcoming draw schedule is always fetched from PrizeBondPK.

- Text files are preferred for each denomination and draw date. If a text file
  exists, only text files for that draw are parsed; associated PDF or other
  files are ignored. Valid text results are inserted into `drawlists` and
  `draw_winners` atomically only if that denomination/date is not already in
  the database. Existing draw results and winners are left unchanged.
- If no text file exists, each linked PDF or other file is recorded as a
  `manual_pdf_review` task in `admin_tasks`; no result is imported
  automatically. Draws with a text file that could not be imported are
  recorded as `missing_draw_result` tasks.
- The automation checks for stored winners after importing results and removes
  matching `missing_draw_result` and `manual_pdf_review` tasks once the draw
  has been entered.
- Task inserts are idempotent. Administrators can track work using the
  `status` values `pending`, `in_progress`, `completed`, and `dismissed`.

The task table is created during database initialization and checked on backend
startup so it is available when automated processing begins.

## Upcoming draw schedule

The `upcoming_draws` table stores PrizeBondPK's scheduled draw dates and
locations. Automation inserts new entries and updates the location for existing
`(draw_date, denomination)` pairs. Its primary key prevents duplicate schedule
entries.

The `cleanup_past_upcoming_draws` pg_cron job runs hourly and invokes the
`cleanup_past_upcoming_draws()` function, which removes entries whose draw date
has passed in Pakistan Standard Time. Database initialization creates the
function before scheduling the job. For an existing database where automatic
initialization is disabled, apply `14-Upcoming-Draws.sql`,
`10-Functions&Triggers.sql`, and `9-Tasks.sql` in that order with a database
administrator. This requires the `pg_cron` extension to be installed and
enabled.

Administrators can manage schedule entries through the API:

- `GET /drawlists/schedule` returns all future schedule entries, ordered by
  draw date and denomination. This read endpoint is public.
- `POST /drawlists/schedule` with JSON `{"denomination": 100, "draw_date":
  "2027-01-15"}` adds a future draw date. Duplicate denomination/date pairs
  return `409 Conflict`; dates that are not in the future in Pakistan time are
  rejected.
- `DELETE /drawlists/schedule/{denomination}/{draw_date}` deletes that exact
  schedule entry. It returns `404 Not Found` if there is no matching entry.

The create and delete operations require an administrator bearer token.

## Manual draw-list upload

An authenticated administrator can add a draw result with `POST /drawlists`
using a JSON body containing the denomination, ISO draw date, and winning
numbers grouped by prize position:

```json
{
  "denomination": 100,
  "draw_date": "2027-01-15",
  "first_prize_numbers": ["123456"],
  "second_prize_numbers": ["234567", "345678", "456789"],
  "third_prize_numbers": ["567890"]
}
```

Each winning-number field is a non-empty array. The first- and second-prize
counts are validated for the selected denomination. Numbers must be in the
`000001`–`999999` range, are stored as six digits, and cannot be duplicated
within a draw. Prize amounts are assigned by the backend according to the
denomination. A draw that already exists for the selected denomination and date
is not replaced; the endpoint returns `409 Conflict`. Newly added draw rows and
winners are inserted atomically, then completed admin tasks for that draw are
removed.

An authenticated administrator can delete an imported draw list with
`DELETE /drawlists/{draw_id}`. The draw's winning-bond rows are deleted
automatically by the database foreign-key cascade. The endpoint returns
`404 Not Found` when the draw ID does not exist.
