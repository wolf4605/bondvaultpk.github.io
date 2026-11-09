"""
* Project Name: BONDVAULT PK

* File: main.py
* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-20 17:39:33

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-21 19:24:42

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

import logging
import traceback
from collections.abc import Awaitable, Callable
from pathlib import Path
from time import perf_counter
from uuid import uuid4

import asyncpg
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from redis.exceptions import RedisError
from scalar_fastapi import AgentScalarConfig, Layout, get_scalar_api_reference
from starlette.exceptions import HTTPException as _HTTPException
from starlette.responses import Response

from src import Tags
from src.configs import AppSettings
from src.routers.admin import router as admin_router
from src.routers.admin_auth import router as admin_auth_router
from src.routers.bonds import router as bond_router
from src.routers.drawlists import (
    router as draw_router,
    user_router as user_drawlists_router,
)
from src.routers.system import router as system_router
from src.routers.user import router as user_router
from src.routers.user_auth import router as user_auth_router
from src.services.admin_audit import record_admin_audit_event
from src.services.email_service import EmailDeliveryError
from src.services.lifespan import lifespan
from src.utilities.auth_tokens import ACCESS_TOKEN_EXPIRES_HEADER, ACCESS_TOKEN_HEADER

# ╔══════════════════════════════════════════════════════════╗
# ║                  CONFIGURING THE LOGGER                  ║
# ╚══════════════════════════════════════════════════════════╝

exception_file_logger = logging.getLogger("application.errors")
API_PREFIXES = ("/admins", "/bonds", "/drawlists", "/system", "/user")
RATE_LIMITED_METHODS = frozenset({"POST", "PUT", "PATCH", "DELETE"})
IP_REQUESTS_PER_MINUTE = 300

# ╔══════════════════════════════════════════════════════════╗
# ║               MAIN APPLICATION ENTRYPOINT                ║
# ╚══════════════════════════════════════════════════════════╝

app = FastAPI(
    debug = True,
    title= AppSettings.Title,
    version= AppSettings.Version,
    description= AppSettings.Description,
    terms_of_service=None,
    contact=AppSettings.Contact[0],
    license_info=AppSettings.License,
    openapi_tags = Tags,
    lifespan=lifespan,
)
"""
The main application variable used to run the Backend.
"""

app.include_router(user_auth_router)
app.include_router(admin_auth_router)
app.include_router(bond_router)
app.include_router(admin_router)
app.include_router(user_router)
app.include_router(draw_router)
app.include_router(user_drawlists_router)
app.include_router(system_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=[ACCESS_TOKEN_HEADER, ACCESS_TOKEN_EXPIRES_HEADER],
)


def _ip_rate_limit_policy(
    path: str,
    method: str,
) -> tuple[str, int, int] | None:
    """Return a stricter per-IP policy for sensitive or expensive endpoints."""
    if path in {"/system", "/system/health"}:
        return None

    policies: dict[str, tuple[str, int, int]] = {
        "/user/auth/login": ("login", 10, 15 * 60),
        "/admins/auth/login": ("login", 10, 15 * 60),
        "/user/auth/register": ("registration", 10, 60 * 60),
        "/user/auth/password-recovery": ("password-recovery", 5, 60 * 60),
        "/system/verification-code": ("verification-code", 5, 60 * 60),
        "/user/auth/password-recovery/complete": (
            "password-recovery-complete",
            10,
            60,
        ),
        "/system/verification-code/verify": (
            "verification-code-verify",
            10,
            60,
        ),
        "/user/auth/check-availability": ("availability", 30, 60),
    }
    if path in policies:
        return policies[path]

    if path.startswith("/bonds/draw-results/"):
        return "bond-search", 120, 60

    if method in RATE_LIMITED_METHODS:
        return "write", 60, 60
    return "read", 300, 60


async def enforce_ip_rate_limit(request: Request) -> None:
    """Limit API traffic by peer IP, with stricter policies where appropriate."""
    path = request.url.path
    if not any(
        path == prefix or path.startswith(f"{prefix}/")
        for prefix in API_PREFIXES
    ):
        return

    client_ip = request.client.host if request.client is not None else "unknown"
    redis_wrapper = request.app.state.redis_wrapper
    route_policy = _ip_rate_limit_policy(path, request.method)
    limits = [
        ("ip:all-api", IP_REQUESTS_PER_MINUTE, 60),
    ]
    if route_policy is not None:
        bucket, limit, window_seconds = route_policy
        limits.append((f"ip:{bucket}", limit, window_seconds))

    for bucket, limit, window_seconds in limits:
        try:
            retry_after = await redis_wrapper.check_rate_limit(
                bucket,
                client_ip,
                limit,
                window_seconds,
            )
        except (ConnectionError, RedisError, OSError, TimeoutError) as error:
            raise _HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="The rate-limiting service is temporarily unavailable.",
            ) from error

        if retry_after is not None:
            raise _HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later.",
                headers={"Retry-After": str(retry_after)},
            )


@app.middleware("http")
async def audit_admin_actions(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    """Handle request exceptions and audit administrator APIs without credentials."""
    started_at = perf_counter()
    try:
        await enforce_ip_rate_limit(request)
        response = await call_next(request)
    except Exception as error:
        response = await handle_app_error(request, error)

    payload = getattr(request.state, "admin_payload", None)
    is_admin_api_request = (
        request.url.path == "/admins"
        or request.url.path.startswith("/admins/")
        or payload is not None
    )
    if is_admin_api_request:
        route_object = request.scope.get("route")
        route_path = getattr(route_object, "path", request.url.path)
        route_summary = (
            getattr(route_object, "summary", None)
            or getattr(route_object, "name", None)
            or route_path
        )
        path_parameters = request.path_params
        subject_id = next(
            (
                str(value)
                for name, value in path_parameters.items()
                if name.endswith("_id") or name in {"draw_date", "denomination"}
            ),
            None,
        )
        subject = route_summary
        if subject_id is not None:
            subject = f"{route_summary} ({subject_id})"
        duration_ms = round((perf_counter() - started_at) * 1000, 3)
        request_id = uuid4()
        client_ip = (
            request.client.host
            if request.client is not None
            else None
        )
        user_agent = request.headers.get("user-agent")
        audit_logger = logging.getLogger("application.audit")
        audit_logger.info(
            "administrator API request",
            extra={
                "event": "admin.api.request",
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
                "admin_id": str(payload.id) if payload is not None else None,
                "request_id": str(request_id),
            },
        )
        try:
            await record_admin_audit_event(
                actor_admin_id=payload.id if payload is not None else None,
                action=f"{request.method} {route_path}",
                subject=subject,
                subject_id=subject_id,
                description=(
                    f"{route_summary}; request completed with HTTP "
                    f"{response.status_code} in {duration_ms} ms."
                ),
                http_method=request.method,
                route=route_path,
                status_code=response.status_code,
                duration_ms=duration_ms,
                client_ip=client_ip,
                user_agent=user_agent,
                request_id=request_id,
            )
        except (
            asyncpg.PostgresError,
            ConnectionError,
            RuntimeError,
            ValueError,
            TimeoutError,
        ):
            audit_logger.exception(
                "administrator API request could not be persisted to the audit table",
                extra={
                    "event": "admin.audit.persistence_failed",
                    "route": route_path,
                    "request_id": str(request_id),
                    "admin_id": str(payload.id) if payload is not None else None,
                },
            )
    return response



# ==================== SCALAR DOCS SETUP ====================

@app.get(
    path= "/",
    include_in_schema=False,
    status_code= 200
)
async def setup_scalar() -> HTMLResponse:
    """
    Overrides the default Swagger UI to a custom Scalar theme.
    """

    css_data:str = f"<head><style>{Path(__file__).parent.joinpath("src").joinpath("static").joinpath("scalar_theme.css").read_text(encoding="utf-8")}</style></head>"
    return get_scalar_api_reference(
        scalar_favicon_url = "https://raw.githubusercontent.com/wolf4605/bondvaultpk.github.io/refs/heads/main/src/assets/logo.svg",
        title= app.title,
        openapi_url= app.openapi_url,
        hide_models= True,
        layout= Layout.MODERN,
        custom_css= css_data,
        agent= AgentScalarConfig(disabled=True)
    )

# ╔══════════════════════════════════════════════════════════╗
# ║                      ERROR HANDLING                      ║
# ╚══════════════════════════════════════════════════════════╝


def _get_exception_message(error: Exception, fallback: str) -> str:
    """Return a safe message for the client response."""
    if not error.args:
        return fallback

    try:
        message = str(error)
    except IndexError:
        return fallback

    return message or fallback


def _get_debug_exception_details(error: Exception) -> dict[str, str]:
    """Return exception type and traceback only when application debugging is enabled."""
    if not app.debug:
        return {}

    return {
        "exception": type(error).__name__,
        "traceback": "".join(
            traceback.format_exception(type(error), error, error.__traceback__)
        ),
    }


@app.exception_handler(_HTTPException)
@app.exception_handler(ConnectionError)
@app.exception_handler(TimeoutError)
@app.exception_handler(ValueError)
@app.exception_handler(RuntimeError)
@app.exception_handler(asyncpg.exceptions.PostgresError)
@app.exception_handler(asyncpg.exceptions.InterfaceError)
@app.exception_handler(Exception)
async def handle_app_error(
    request: Request,
    error: ConnectionError|TimeoutError|ValueError|RuntimeError|asyncpg.exceptions.PostgresError|asyncpg.exceptions.InterfaceError|_HTTPException|Exception
) -> JSONResponse:
    """Log the full exception and return the corresponding API error response."""

    exception_file_logger.error(
        "Endpoint exception [%s %s] (%s)",
        request.method,
        request.url.path,
        type(error).__name__,
        exc_info=(type(error), error, error.__traceback__),
    )
    if not app.debug:
        logging.getLogger("application.error_indicator").error(
            "Endpoint failed [%s %s]",
            request.method,
            request.url.path,
        )

    if isinstance(error, _HTTPException):
        status_name = next(
            (
                name
                for name, code in vars(status).items()
                if name.startswith("HTTP_") and code == error.status_code
            ),
            f"HTTP_{error.status_code}"
        )
        return JSONResponse(
            status_code = error.status_code,
            headers = error.headers,
            content= {
                "error" : {
                    "status_code" : error.status_code,
                    "code" : status_name,
                    "message" : error.detail,
                    **_get_debug_exception_details(error),
                }
            }
        )
    elif isinstance(
        error,
        (ConnectionError, asyncpg.exceptions.PostgresConnectionError),
    ):
        status_code = 503
        code = "DATABASE_CONNECTION_FAILURE"
        fallback_message = "The database connection failed."
    elif isinstance(error, (TimeoutError, asyncpg.exceptions.QueryCanceledError)):
        status_code = 504
        code = "TIMEOUT"
        fallback_message = "The database operation timed out."
    elif isinstance(error, asyncpg.exceptions.UniqueViolationError):
        status_code = 409
        code = "DATABASE_CONSTRAINT_VIOLATION"
        fallback_message = "A database constraint was violated."
    elif isinstance(error, EmailDeliveryError):
        status_code = 503
        code = "EMAIL_DELIVERY_FAILURE"
        fallback_message = "The email service is unavailable."
    elif isinstance(error, ValueError):
        status_code = 400
        code = "INVALID_VALUE"
        fallback_message = "An invalid value was provided."
    elif isinstance(error, RuntimeError):
        status_code = 500
        code = "DATABASE_QUERY_ERROR"
        fallback_message = "The database query failed."
    elif isinstance(error, asyncpg.exceptions.PostgresError):
        status_code = 500
        code = "DATABASE_ERROR"
        fallback_message = "A database error occurred."
    elif isinstance(error, asyncpg.exceptions.InterfaceError):
        status_code = 500
        code = "DATABASE_INTERFACE_ERROR"
        fallback_message = "A database operation could not be completed."
    elif isinstance(error, Exception):
        fallback_message = "An unexpected error occurred."
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "status_code": 500,
                    "code": "INTERNAL_ERROR",
                    "message": (
                        _get_exception_message(error, fallback_message)
                        if app.debug
                        else fallback_message
                    ),
                    **_get_debug_exception_details(error),
                }
            },
        )
    else:
        raise TypeError(f"Unsupported application error type: {type(error).__name__}")

    message = (
        _get_exception_message(error, fallback_message)
        if app.debug
        else fallback_message
    )

    return JSONResponse(
        status_code=status_code,
        content={
            "error": {
                "status_code": status_code,
                "code": code,
                "message": message,
                **_get_debug_exception_details(error),
            }
        },
    )
