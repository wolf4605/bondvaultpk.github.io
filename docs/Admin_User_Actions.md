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

The `admin_invites` table is created by database initialization. Apply
`src/database/schema/12-Admin-Invites.sql` manually if initialization is not
enabled for the deployment.

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
