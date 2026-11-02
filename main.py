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

import asyncpg
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from scalar_fastapi import AgentScalarConfig, Layout, get_scalar_api_reference
from starlette.exceptions import HTTPException as _HTTPException
from starlette.responses import Response

from src import Tags
from src.configs import AppSettings
from src.routers.admin import router as admin_router
from src.routers.admin_auth import router as admin_auth_router
from src.routers.bonds import router as bond_router
from src.routers.system import router as system_router
from src.routers.user import router as user_router
from src.routers.user_auth import router as user_auth_router
from src.services.lifespan import lifespan
from src.utilities.auth_tokens import ACCESS_TOKEN_EXPIRES_HEADER, ACCESS_TOKEN_HEADER

# ╔══════════════════════════════════════════════════════════╗
# ║                  CONFIGURING THE LOGGER                  ║
# ╚══════════════════════════════════════════════════════════╝

exception_file_logger = logging.getLogger("application.errors")

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
app.include_router(system_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=[ACCESS_TOKEN_HEADER, ACCESS_TOKEN_EXPIRES_HEADER],
)


@app.middleware("http")
async def audit_admin_actions(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    """Handle request exceptions and audit administrator APIs without credentials."""
    started_at = perf_counter()
    try:
        response = await call_next(request)
    except Exception as error:
        response = await handle_app_error(request, error)

    if request.url.path.startswith("/admins/"):
        payload = getattr(request.state, "admin_payload", None)
        audit_logger = logging.getLogger("application.audit")
        audit_logger.info(
            "administrator API request",
            extra={
                "event": "admin.api.request",
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round((perf_counter() - started_at) * 1000, 3),
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
