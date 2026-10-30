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

The application validates the secret during startup. Startup also opens the
database connection pool, which is closed during application shutdown.

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

There is no refresh token or server-side session store. Token renewal relies
on clients accepting the replacement response header. Tokens remain valid
until expiry if the account password changes; account deletion invalidates
them on the next request because the account is reloaded each time.

## Administrator audit logging

Successful and failed administrator logins, plus every request under
`/admins/`, generate structured events through the `application.audit`
logger. Events record the operation, status, duration, and authenticated
administrator ID where available. Passwords, bearer tokens, and request
bodies are not logged.
