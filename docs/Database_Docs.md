# Database access

`src.database.wrapper.Database` is the application's basic asynchronous
PostgreSQL wrapper. It owns the `asyncpg` connection pool and exposes raw SQL
operations. Application code issues parameterized SQL directly; there is no
repository layer.

## Organization

- `src/database/wrapper.py` defines `Database` and the shared `DB` instance.
- `src/database/schema/` contains database schema, index, task, function, and
  trigger scripts.
- `src/database/__init__.py` re-exports `DB` and `Database`.

## Pool lifecycle

The shared `DB` is created at import time without opening a connection. The
FastAPI lifespan opens the pool during startup and closes it during shutdown.
For a separate database instance:

```python
from src.database import Database

db = Database(dsn="postgresql://...")
await db.pool_create()
try:
    rows = await db.fetch(
        'SELECT "id", "email" FROM "users" WHERE "username" = $1',
        username,
    )
finally:
    await db.pool_close()
```

Pool size, connection timeout, and command timeout default to the values in
`src.configs.DBConfigs`. Calling a query before creating the pool raises
`ConnectionError`.

## Raw SQL methods

Bind every runtime value using asyncpg's positional parameters (`$1`, `$2`,
etc.). Do not interpolate values into query strings.

| Method | Result | Purpose |
| --- | --- | --- |
| `execute(query, *args)` | `str` | Execute a statement and return PostgreSQL's command status. |
| `fetch(query, *args)` | `list[asyncpg.Record]` | Return all rows. |
| `fetchrow(query, *args)` | `asyncpg.Record \| None` | Return the first row, if any. |
| `fetchval(query, *args, column=0)` | `Any` | Return one value from the first row. |
| `connection()` | async context manager | Acquire and release a pooled connection. |
| `transaction()` | async context manager | Run connection operations atomically. Exceptions roll the transaction back. |
| `check_health()` | `bool` | Check whether `SELECT 1` succeeds. |

Identifiers such as table and column names cannot be bound as SQL values. Keep
any dynamic identifier limited to a fixed, validated allowlist.

`asyncpg.Record` values can be converted into response models with
`Model.model_validate(dict(record))`. The currently used account and auth
models are in `src/models/admin_model.py`, `src/models/user_model.py`, and
`src/models/auth_model.py`. Select only the columns required by the caller,
especially for sensitive fields such as password hashes.

## Schema and models

Schema SQL is maintained in `src/database/schema/`. PostgreSQL constraints
remain authoritative; constraint errors are surfaced by the wrapper rather
than converted into success-shaped results.

<<<<<<< HEAD
The schema stores primary keys as UUIDs and uses plural table names such as
`users` and `admins`. `CREATE TABLE IF NOT EXISTS` does not migrate existing
columns or foreign keys; incompatible existing databases need an explicit
migration.
=======
### `admins`

Registration accepts `src.models.admin_model.AdminRegister`; its password
validator hashes the supplied password before insertion. Results use
`AdminInfo`, which never exposes `password_hash`.

| Method | Description |
| --- | --- |
| `Admin.register(data)` | Register an administrator; return its public fields. |
| `Admin.get_by_id(admin_id)` | Look up by UUID. |
| `Admin.get_by_username(username)` | Look up by unique username. |
| `Admin.get_by_email(email)` | Look up by unique email. |
| `Admin.list(limit=50, offset=0)` | Paginate administrators. |
| `Admin.update(admin_id, AdminUpdate(...))` | Update supplied profile/admin fields. |
| `Admin.set_password(admin_id, password_hash)` | Replace the stored password hash. |
| `Admin.delete(admin_id)` | Delete an administrator. |

### `users`

Registration accepts `src.models.user_model.UserRegister`, which validates the
email/contact fields and hashes the supplied password. `UserInfo` excludes the
password hash.

| Method | Description |
| --- | --- |
| `User.register(data)` | Register a user; return public fields. |
| `User.get_by_id(user_id)` | Look up by UUID. |
| `User.get_by_username(username)` | Look up by unique username. |
| `User.get_by_email(email)` | Look up by unique email. |
| `User.list(limit=50, offset=0)` | Paginate users. |
| `User.update(user_id, UserUpdate(...))` | Update supplied profile fields. |
| `User.verify(user_id, admin_id)` | Verify a user and record the administrator. |
| `User.record_login(user_id)` | Set `last_login` to the database's current time. |
| `User.set_password(user_id, password_hash)` | Replace the stored password hash. |
| `User.delete(user_id)` | Delete a user; schema cascades remove their bondlists, listings, and reports. |

`set_password` expects an already hashed value. Hash passwords in the
authentication/application layer before calling it.

### `bondlists`

`Bondlist.create` accepts `src.models.bonds_models.BondListCreate`; list responses use
`src.models.bonds_models.BondListInfo` and include the bond numbers.

| Method | Description |
| --- | --- |
| `Bondlist.create(data)` | Create a denomination-specific list for a user. |
| `Bondlist.get(bondlist_id)` | Get one list and its bond numbers. |
| `Bondlist.list_for_user(user_id)` | Get all lists and bond numbers for a user. |
| `Bondlist.update(bondlist_id, BondlistUpdate(...))` | Change a list's denomination. |
| `Bondlist.delete(bondlist_id)` | Delete a list and its bonds. |

The schema enforces one bondlist per user and denomination.

### `bonds`

`Bond.register` accepts `src.models.bonds_models.RegisterBonds`, which allows one bond
number or a list. It returns the number of newly inserted bonds; duplicates
already in the same list are ignored.

| Method | Description |
| --- | --- |
| `Bond.register(data)` | Add one or more bond numbers to a list. |
| `Bond.list_for_bondlist(bondlist_id)` | Return sorted bond numbers in a list. |
| `Bond.find(bond_number)` | Find a bond's list, denomination, and owner as `BondLocation`. |
| `Bond.move(bond_number, source_bondlist_id, target_bondlist_id)` | Move a bond between lists of the same denomination. |
| `Bond.delete(bondlist_id, bond_number)` | Remove one bond. |
| `Bond.delete_all(bondlist_id)` | Remove all bonds in a list and return the count. |

The move operation is transactional and raises `ValueError` when the source or
target lists have different denominations.

### `drawlists`

Create and update inputs use `src.models.bonds_models.Drawlist` and
`src.models.bonds_models.DrawlistUpdate`. Drawlists are identified by their
composite key `(draw_date, denomination)`.

| Method | Description |
| --- | --- |
| `Drawlist.create(data)` | Insert the result or replace result fields on key conflict. |
| `Drawlist.get(draw_date, denomination)` | Get one result by composite key. |
| `Drawlist.list(denomination=None, limit=50, offset=0)` | Paginate all results or filter by denomination. |
| `Drawlist.update(draw_date, denomination, data)` | Update winner/prize fields. |
| `Drawlist.delete(draw_date, denomination)` | Delete one result. |

### `market`

Create/update inputs and returned rows use `MarketCreate`, `MarketUpdate`, and
`MarketInfo` from `src.models.market_model`.

| Method | Description |
| --- | --- |
| `Market.create(data)` | Publish a `buy` or `sell` listing. |
| `Market.get(listing_id)` | Look up a listing. |
| `Market.list(category=None, posted_by=None, limit=50, offset=0)` | Paginate listings with optional category/owner filters. |
| `Market.update(listing_id, data)` | Update supplied listing fields. |
| `Market.delete(listing_id)` | Delete a listing. |

Categories are limited to `buy` and `sell`; prices cannot be negative.

### `reports`

Create and returned records use `ReportCreate` and `ReportInfo`.

| Method | Description |
| --- | --- |
| `Report.create(data)` | Submit a report in `pending` state. |
| `Report.get(report_id)` | Look up a report. |
| `Report.list(status=None, reported_by=None, limit=50, offset=0)` | Paginate and optionally filter by state or submitter. |
| `Report.resolve(report_id, admin_id, response=None)` | Resolve a pending report and record the admin/response. |
| `Report.delete(report_id)` | Delete a report. |

`resolve` returns `None` if the report does not exist or is no longer pending.

### `blacklist`

Create and returned records use `BlacklistCreate` and `BlacklistInfo`. A null
`duration` means the blacklist entry is permanent.

| Method | Description |
| --- | --- |
| `Blacklist.add(data)` | Add an email/contact entry. |
| `Blacklist.find(email=None, contact=None)` | Find matching active entries; at least one criterion is required. |
| `Blacklist.list(limit=50, offset=0)` | Paginate all entries, including expired entries. |
| `Blacklist.update(blacklist_id, BlacklistUpdate(...))` | Update identifying fields or expiry time. |
| `Blacklist.remove(blacklist_id)` | Remove an entry. |
| `Blacklist.purge_expired()` | Remove expired temporary entries and return the count. |

The database trigger associated with permanent entries also removes matching
user accounts. Treat `Blacklist.add` accordingly.

## Pydantic models

Table request and public response models are in `src/models/`:

- Administrator models: `admin_model.AdminRegister`, `AdminInfo`, and
  `AdminUpdate`.
- User models: `user_model.UserRegister`, `UserInfo`, and `UserUpdate`.
- Bond and draw models: `bonds_models.BondListCreate`, `BondListInfo`,
  `RegisterBonds`, `Drawlist`, `BondlistUpdate`, `BondLocation`, and
  `DrawlistUpdate`.
- Market models: `market_model.MarketCreate`, `MarketInfo`, and `MarketUpdate`.
- Report models: `report_model.ReportCreate` and `ReportInfo`.
- Blacklist models: `blacklist_model.BlacklistCreate`, `BlacklistInfo`, and
  `BlacklistUpdate`.

All of these are also re-exported from `src.models`. `database_models` remains
as a backward-compatible import module for database operation models.

Update models use optional fields. Fields omitted from an update are preserved;
explicitly passing `None` requests a SQL `NULL` value where the schema permits
it. Schema constraints (including `NOT NULL`, unique keys, and foreign keys)
remain authoritative and PostgreSQL constraint errors are not suppressed.

## Schema identifier compatibility

The schema stores primary keys as UUIDs. Foreign-key columns referencing users
or administrators are UUIDs as well, and refer to the plural table names
`users` and `admins`. The wrapper accepts UUID strings at its public methods and
converts them to UUID values before database calls. The schema files use
`CREATE TABLE IF NOT EXISTS`; applying the corrected definitions does not
automatically migrate an existing database with incompatible column types or
foreign keys. Existing installations need an explicit migration before using
these repositories.
>>>>>>> 650ab09f5fa893458b064e3f3afe2646e080165a
