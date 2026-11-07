# User city and address migration

New users must provide a non-empty city and address. The `users` table stores
`city` as `VARCHAR(100)` and `address` as `TEXT`; both columns are required
after migration.

Existing accounts must be backfilled with their actual values before the
initializer enforces `NOT NULL`. When database initialization runs against an
existing database, it first adds both columns as nullable. If any users still
have a `NULL` value, initialization stops and reports how many records need
updating. It does not invent profile data.

For each existing user, provide the real city and address using an
administrator-controlled database connection. For example:

```sql
UPDATE "users"
SET "city" = '<actual city>',
    "address" = '<actual street or postal address>'
WHERE "id" = '<user UUID>';
```

After every existing account has been backfilled, rerun database initialization.
It verifies that no values are missing, then applies `NOT NULL` to both
columns. Fresh databases create the columns as `NOT NULL` directly.
