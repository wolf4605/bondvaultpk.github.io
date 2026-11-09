"""Persistence helpers for administrator API audit events."""

from pathlib import Path
from uuid import UUID

from ..database import DB, Database


async def ensure_admin_audit_table(database: Database = DB) -> None:
    """Create the audit table and indexes if they are not yet installed."""
    table_exists = await database.fetchval(
        """
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'admin_audit'
        )
        """
    )
    if table_exists:
        return

    schema_file = (
        Path(__file__).resolve().parent.parent
        / "database"
        / "schema"
        / "15-Admin-Audit.sql"
    )
    await database.execute(schema_file.read_text(encoding="utf-8"))


async def record_admin_audit_event(
    *,
    actor_admin_id: UUID | None,
    action: str,
    subject: str,
    subject_id: str | None,
    description: str,
    http_method: str,
    route: str,
    status_code: int,
    duration_ms: float,
    client_ip: str | None,
    user_agent: str | None,
    request_id: UUID,
    database: Database = DB,
) -> None:
    """Persist one administrator API request without storing request secrets."""
    await database.execute(
        """
        INSERT INTO "admin_audit" (
            "actor_admin_id", "action", "subject", "subject_id",
            "description", "http_method", "route", "status_code",
            "duration_ms", "client_ip", "user_agent", "request_id"
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        """,
        actor_admin_id,
        action,
        subject,
        subject_id,
        description,
        http_method,
        route,
        status_code,
        duration_ms,
        client_ip,
        user_agent,
        request_id,
    )
