# Administrator account and user actions

## Email configuration

Set `SMTP_Server`, `SMTP_Port`, `Email`, and `Password` in the environment or
`src/configs/.env`. Use a provider-issued app password where available. Port
465 uses implicit TLS; other configured ports use STARTTLS. Account-action
endpoints return an explicit service error when required SMTP settings are
missing or delivery fails.

Plain-text email subjects and bodies are stored as editable files in
`src/mail_templates/`. Each template starts with a `Subject:` line, followed
by a blank line and the message body. Use `$placeholder` names for values
inserted by the email service.

## Administrator invitations

Only a superuser can create administrators with `POST /admins`. New admins
receive their username and email address plus a single-use activation token;
the API never emails a reusable password. The token expires after 24 hours.
The invited administrator sets a password of at least 12 characters with
`POST /admins/auth/activate`, providing the email, token, and new password.
Superusers can rotate and resend a pending invitation with
`POST /admins/{admin_id}/invite`.
They can delete another administrator with `DELETE /admins/{admin_id}`.
Administrators cannot delete their own account, and the final superuser account
cannot be deleted. Deleting an administrator also removes any pending
invitation, revokes their active sessions, and emails an account-deletion notice.
Superusers can set the password of a non-superuser administrator with
`PUT /admins/{admin_id}/password`, sending
`{"new_password":"a-strong-password"}`. Passwords must be 12–256 characters.
The new password is emailed to that administrator, and their active sessions
are revoked. This endpoint cannot change a superuser's password.

The `admin_invites` table is created by database initialization. Apply
`src/database/schema/12-Admin-Invites.sql` manually if initialization is not
enabled for the deployment.

## Administrator audit log

Administrator API requests are recorded in the `admin_audit` table, including
the acting administrator when authenticated, action and route, subject and
subject ID when present, result status, duration, request ID, client IP,
user-agent, and event timestamp. Requests to `/admins` are recorded even when
authentication fails; authenticated administrator requests on other API
prefixes are also recorded. Request bodies, passwords, tokens, and other
credentials are not stored.

Any authenticated administrator can browse the newest audit events with
`GET /admins/audit?limit=100&offset=0`. The limit can be between 1 and 500.
Deleting an administrator preserves audit history and changes their actor ID
to `NULL`.

The application creates `admin_audit` at startup. Deployments whose database
role cannot create tables should apply `src/database/schema/15-Admin-Audit.sql`
with a database administrator before starting the application.

## User moderation

- `GET /admins/market/listings` returns all marketplace listings with the
  owner's username and email address.
- `DELETE /admins/market/listings/{listing_id}` deletes a listing and emails
  its owner. If email delivery fails, the response states that deletion has
  already taken effect.
- `GET /admins/users/blacklist` returns active blacklist entries, including
  permanent entries and temporary entries that have not expired. Each record
  includes its email, contact, expiry, creation time, and matching account
  details when that account still exists. It is restricted to authenticated
  administrators.
- `POST /admins/users/{user_id}/approve` sets `is_verified`, records the
  approving admin, and emails the user.
- `POST /admins/users/{user_id}/blacklist` accepts an optional
  `duration_until` timestamp and optional `reason` string. Send `{}` for a
  permanent blacklist without a reason; the existing database trigger removes
  permanently blacklisted users. A future timestamp creates a temporary
  blacklist. Active blacklists prevent login and invalidate authenticated user
  requests. The reason is included in active blacklist listings.
- `DELETE /admins/users/{user_id}/blacklist` removes an active blacklist from an
  existing user, revokes any remaining sessions, and emails the user. Since a
  permanent blacklist deletes the account, it cannot be reversed with this
  endpoint. An administrator must remove the permanent blacklist record before
  the user can register again.
- `DELETE /admins/users/{user_id}` removes the user and emails the account
  address captured before deletion.

All user moderation endpoints require an authenticated administrator.
Email is sent after the database action has committed. If SMTP delivery fails,
the response indicates that the account action already took effect. The
failure is logged for an operator to retry notification delivery using the
account email and action details.

Administrator deletion and password changes require an authenticated
superuser. If email delivery or active-session revocation fails after either
action, the endpoint returns a service error and states that the action has
already taken effect. The administrator password-change email contains the
new password; it is never included in the API response or application logs.
