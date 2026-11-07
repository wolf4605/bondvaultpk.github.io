# Automated draw-list processing

The backend runs the draw-list workflow once after startup and then daily at
10:00 PM Pakistan Standard Time (UTC+05:00). It reads the National Savings
draw-list pages using `src.utilities.scrapper`.

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

The admin-managed `upcoming_draws` table stores one scheduled draw date per
denomination. Its `(draw_date, denomination)` primary key prevents duplicate
schedule entries. Add and maintain schedule rows directly in PostgreSQL; no
official future-draw schedule feed is currently imported by the scraper.

The `cleanup_past_upcoming_draws` pg_cron job runs hourly and removes entries
whose draw date has passed in Pakistan Standard Time. Database initialization
creates the table and schedules the job. For an existing database where
automatic initialization is disabled, apply `14-Upcoming-Draws.sql` and the
updated `9-Tasks.sql` with a database administrator. This requires the
`pg_cron` extension to be installed and enabled.

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

## Manual text draw-list upload

An authenticated administrator can add a draw result with
`POST /drawlists` as multipart form data containing `denomination`, `draw_date`
(ISO `YYYY-MM-DD`), and a `.txt` file. The file must contain first-, second-,
and third-prize sections with their winning bond numbers. The parser accepts
the National Savings text layout, with a prize heading followed by the winning
number(s), for example:

```text
First Prize of Rs. 700,000/-
123456
Second Prize of Rs. 200,000/-
234567 345678 456789
Third Prize of Rs. 1,000/- each)
567890
```

The first- and second-prize winner counts are validated for the selected
denomination. All three prize sections must contain winners. Numbers are stored
as six digits; shorter numeric entries are zero-padded. Missing prize
sections, invalid numbers, and duplicate numbers are rejected before database
changes. A draw that already exists for the selected denomination and date is
not replaced; the endpoint returns `409 Conflict`. Newly added draw rows and
winners are inserted atomically, then completed admin tasks for that draw are
removed.
