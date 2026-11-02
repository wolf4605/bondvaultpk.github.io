# User and administrator authentication

The API issues short-lived, signed JWT bearer access tokens for users and
administrators. Authentication is separate for each role, and tokens cannot
be used across roles.

## Configuration

Set `JWT_SECRET_KEY` in the process environment or `src/configs/.env` to a
random secret containing at least 32 bytes. Do not commit a real signing key.
`src/configs/example.env` contains a placeholder.

The token-signing algorithm is `HS256`, configured in
`src/configs/auth_configs.py`. The idle timeout is
`ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES` in the same file and defaults to 10
minutes. Change that value to tune the inactivity window.

The application validates the secret during startup. Startup also connects to
the database and Redis session store; both connections close during shutdown.
Set `REDIS_URL` to the Redis connection URL (defaults to
`redis://localhost:6379/0`). The Docker Compose setup starts a local Redis
service on that address; an API container on the same Compose network should
use `redis://redis:6379/0`.

## Sign in from Swagger UI

Open the API documentation and select **Authorize**. Swagger displays separate
user and administrator OAuth2 password-flow forms. Enter the account username
or email address in the `username` field, enter the password, and authorize.
Swagger sends a form-encoded request to the selected login endpoint and stores
the returned bearer token for the matching OAuth2 scheme.

## Login endpoints

Both endpoints accept OAuth2 `application/x-www-form-urlencoded` credentials.
Use the standard `username` form field for either a username or email address.
Passwords are verified against the Argon2 hashes stored in the database;
login failures use a generic response and do not reveal whether the username
exists.

### User login

`POST /users/auth/login`

```http
Content-Type: application/x-www-form-urlencoded

username=user123&password=your-password
```

The response contains a bearer `access_token`, `expires_in` in seconds, and a
public user `payload` represented by `UserInfo`.

### Administrator login

`POST /admins/auth/login`

Use the same form fields. The response contains an administrator access token
and a public `AdminInfo` payload.

Tokens include the account UUID in `sub` and a role claim (`user` or `admin`).
The API resolves the current database record for each protected request, so
deleted accounts and role-mismatched tokens are rejected. Password hashes are
never included in authentication payloads.

## Authenticated payloads and token renewal

Send the access token in the standard header:

```http
Authorization: Bearer <access_token>
```

For example, `GET /users/me` and `GET /admins/me` return the authenticated
`UserInfo` and `AdminInfo` respectively. Endpoint functions receive the
principal as a typed dependency payload, so callers do not submit a separate
user or administrator ID:

```python
async def get_user_info(
    payload: Annotated[UserInfo, Depends(get_current_user)],
) -> UserInfo:
    return payload
```

Every successful authenticated request returns a renewed token in
`X-Access-Token` and its configured lifetime in
`X-Access-Token-Expires-In`. Clients must replace their stored access token
with the value of `X-Access-Token` after each authenticated response. This
makes the expiry a sliding inactivity timeout: an API call made after five
idle minutes returns a token with a fresh ten-minute lifetime. If the client
does not store the replacement token, the original token expires ten minutes
after it was issued.

The response headers are exposed by the CORS middleware for browser clients.
The middleware currently permits all origins and does not allow cookies or
other credential-based browser authentication; restrict allowed origins in
deployment if the frontend origin is known.

There is no refresh token; token renewal relies on clients accepting the
replacement response header. The API persists active sessions in Redis, and
each renewed token remains associated with the same server-side session.

## Logout and password changes

Use the matching authenticated logout endpoint to revoke the current session:

- `POST /users/auth/logout`
- `POST /admins/auth/logout`

Changing a password revokes all active sessions for that account:

- `POST /users/change-password`
- `POST /admins/change-password`

After logout or a successful password change, discard the stored access token.
The API does not return a replacement token on either response. Previously
issued tokens for a revoked session are rejected on the next request.

Tokens issued before session tracking was added do not include a session ID
and require the account to sign in again.

## Active user counts

`GET /system/active-users` is public and returns `total_registered_users` and
`currently_online_users`. A user is counted as online while at least one of
their Redis sessions is unexpired and the corresponding account still exists.

## Administrator audit logging

Successful and failed administrator logins, plus every request under
`/admins/`, generate structured events through the `application.audit`
logger. Events record the operation, status, duration, and authenticated
administrator ID where available. Passwords, bearer tokens, and request
bodies are not logged.
