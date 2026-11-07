# BondVault PK

## Draw-list scraper source

Draw-list automation supports two sources with a shared output format:

| `SCRAPER_SOURCE` | Source |
| --- | --- |
| `national_savings` | National Savings Pakistan (default) |
| `prizebondpk` | PrizeBondPK |

Set `SCRAPER_SOURCE` in `src/configs/.env` or the deployment environment to
choose the source. Both implementations provide draw dates, source URLs, and
first-, second-, and third-prize numbers to the same import pipeline.

## SMTP email setup

The backend sends account and email-verification messages through SMTP. Configure
these settings using environment variables in the deployment environment, or
locally in `src/configs/.env`:

| Variable | Description | Example |
| --- | --- | --- |
| `SMTP_Server` | SMTP hostname | `smtp.gmail.com` |
| `SMTP_Port` | SMTP port; use `587` for STARTTLS or `465` for implicit TLS | `587` |
| `Email` | Sender/login email address | `your-account@gmail.com` |
| `Password` | SMTP password or provider app password | Do not commit this value |

### Gmail example

1. Enable 2-Step Verification on the Google account that will send mail.
2. Create an App Password for the backend. Use this generated password as
   `Password`; do not use the account's normal Google password.
3. Configure `SMTP_Server=smtp.gmail.com`, `SMTP_Port=587`, `Email` with the
   sender's full Gmail address, and `Password` with the App Password.
4. Restart the backend so it loads the new settings.

For another provider, use its SMTP hostname and credentials. Port `587` uses
STARTTLS; port `465` uses TLS immediately on connection. Make sure the provider
allows SMTP access for the account.

`SMTP_Server` must be a hostname only, without `https://`, `smtp://`, a path,
or a port suffix. For example, use `smtp.gmail.com`, not
`https://smtp.gmail.com`. Supported ports are `25`, `465`, `587`, and `2525`;
for Gmail, use `587` or `465`.

### Local development and deployment

For local development, create `src/configs/.env` with the four SMTP variables.
Keep this file private and out of version control. For hosted deployments, add
the same names and values to the platform's environment-variable or secret
settings instead of uploading a `.env` file.

The backend also includes these public endpoints:

- `POST /system/verification-code` with `{"email":"person@example.com"}` sends
  a six-digit code. The code is not returned by the API; it expires in 10
  minutes. Requests are limited to one per email per minute and five per client
  IP per hour.
- `POST /system/verification-code/verify` with
  `{"email":"person@example.com","code":"123456"}` consumes a valid code once.
  A code is removed after successful verification or five invalid attempts.
- `POST /users/auth/password-recovery` requests a recovery code. Its response is
  the same whether or not an eligible account exists.
- `POST /users/auth/password-recovery/complete` accepts
  `{"email":"person@example.com","code":"123456","new_password":"a-strong-password"}`
  to reset the password. Passwords must be at least 12 characters. Successful
  recovery revokes all active sessions for that user.

Redis must be available for verification codes and rate limits. SMTP delivery
errors are returned as API errors; codes whose delivery fails are discarded.