"""Basic asynchronous PostgreSQL wrapper for parameterized raw SQL."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Any, cast

import asyncpg

from ..configs import DBConfigs
from ..logging import get_logger

logger = get_logger()


class Database:
    """Manage an asyncpg pool and expose its basic SQL operations."""

    def __init__(
        self,
        dsn: str = DBConfigs.CONNECTION_STRING,
        *,
        min_connects: int = DBConfigs.DB_MIN_CONNECTIONS,
        max_connects: int = DBConfigs.DB_MAX_CONNECTIONS,
        timeout: float = DBConfigs.DB_TIMEOUT,
        command_timeout: float | None = DBConfigs.DB_COMMAND_TIMEOUT,
    ) -> None:
        if min_connects < 1:
            raise ValueError("min_connects must be 1 or greater than 1.")
        if max_connects < min_connects:
            raise ValueError("max_connects must be greater than min_connects.")
        if timeout <= 0:
            raise ValueError("timeout must be greater than 0.")
        if command_timeout is not None and command_timeout <= 0:
            raise ValueError("command timeout must be greater than 0.")

        self._dsn = dsn
        self._min_connects = min_connects
        self._max_connects = max_connects
        self._timeout = timeout
        self._command_timeout = command_timeout
        self._pool: asyncpg.Pool | None = None

    @property
    def is_initialized(self) -> bool:
        """Return whether the connection pool exists."""
        return self._pool is not None

    @staticmethod
    def _validate_query(query: str) -> None:
        """Reject empty or non-string SQL before contacting PostgreSQL."""
        if not isinstance(query, str):
            raise TypeError(
                f"SQL Query must be a non-empty string. Instead got {type(query)}"
            )
        if not query.strip():
            raise ValueError("SQL Query must be a non-empty string.")

    async def pool_create(self) -> None:
        """Create the connection pool if it does not already exist."""
        if self._pool is not None:
            return

        logger.info(
            "Opening PostgreSQL connection pool (host=%s, port=%s, database=%s).",
            DBConfigs.POSTGRES_HOST,
            DBConfigs.POSTGRES_PORT,
            DBConfigs.POSTGRES_DB,
        )
        try:
            self._pool = await asyncpg.create_pool(
                dsn=self._dsn,
                min_size=self._min_connects,
                max_size=self._max_connects,
                timeout=self._timeout,
                command_timeout=self._command_timeout,
            )
        except Exception as error:
            self._pool = None
            raise ConnectionError(
                "Unable to open the PostgreSQL connection pool."
            ) from error

    async def pool_close(self) -> None:
        """Close the pool and release all database connections."""
        if self._pool is None:
            return

        pool = self._pool
        try:
            await pool.close()
            self._pool = None
            logger.info("PostgreSQL connection pool closed.")
        except Exception as error:
            logger.error("Could not close the PostgreSQL connection pool: %s", error)
            raise ConnectionError(
                "Unable to close the PostgreSQL connection pool."
            ) from error

    async def reconnect(self) -> None:
        """Replace the current pool with a newly established one."""
        await self.pool_close()
        await self.pool_create()

    def _require_pool(self) -> asyncpg.Pool:
        """Return the active pool or raise if it has not been initialized."""
        if self._pool is None:
            raise ConnectionError("Database is not initialized.")
        return self._pool

    @asynccontextmanager
    async def connection(self) -> AsyncGenerator[asyncpg.Connection]:
        """Yield one pooled connection and always return it to the pool."""
        pool = self._require_pool()
        try:
            async with pool.acquire() as raw_connection:
                yield cast(asyncpg.Connection, raw_connection)
        except (
            asyncpg.PostgresError,
            ConnectionError,
            RuntimeError,
            ValueError,
            TimeoutError,
        ):
            raise
        except Exception as error:
            raise ConnectionError(
                "An error occurred while connecting to the database."
            ) from error

    @asynccontextmanager
    async def transaction(self) -> AsyncGenerator[asyncpg.Connection]:
        """Yield a connection inside a transaction managed by the wrapper."""
        async with self.connection() as connection:
            try:
                async with connection.transaction():
                    yield connection
            except (
                asyncpg.PostgresError,
                ConnectionError,
                RuntimeError,
                ValueError,
                TimeoutError,
            ):
                raise
            except Exception as error:
                raise ConnectionError(
                    "The database transaction could not be completed."
                ) from error

    async def execute(self, query: str, *args: Any) -> str:
        """Execute a write statement and return asyncpg's status string."""
        self._validate_query(query)
        try:
            async with self.connection() as connection:
                return await connection.execute(query, *args)
        except (
            asyncpg.PostgresError,
            ConnectionError,
            RuntimeError,
            ValueError,
            TimeoutError,
        ):
            raise
        except Exception as error:
            raise RuntimeError("An error occurred while executing the query.") from error

    async def fetch(self, query: str, *args: Any) -> list[asyncpg.Record]:
        """Execute a query and return all rows as asyncpg records."""
        self._validate_query(query)
        try:
            async with self.connection() as connection:
                return await connection.fetch(query, *args)
        except (
            asyncpg.PostgresError,
            ConnectionError,
            RuntimeError,
            ValueError,
            TimeoutError,
        ):
            raise
        except Exception as error:
            raise RuntimeError("The database query failed.") from error

    async def fetchrow(self, query: str, *args: Any) -> asyncpg.Record | None:
        """Execute a query and return its first row, if one exists."""
        self._validate_query(query)
        try:
            async with self.connection() as connection:
                return await connection.fetchrow(query, *args)
        except (
            asyncpg.PostgresError,
            ConnectionError,
            RuntimeError,
            ValueError,
            TimeoutError,
        ):
            raise
        except Exception as error:
            raise RuntimeError("The database row query failed.") from error

    async def fetchval(
        self,
        query: str,
        *args: Any,
        column: int = 0,
    ) -> Any:
        """Execute a query and return one column from its first row."""
        self._validate_query(query)
        try:
            async with self.connection() as connection:
                return await connection.fetchval(query, *args, column=column)
        except (
            asyncpg.PostgresError,
            ConnectionError,
            RuntimeError,
            ValueError,
            TimeoutError,
        ):
            raise
        except Exception as error:
            raise RuntimeError("The database value query failed.") from error

    async def check_health(self) -> bool:
        """Check whether the database responds to a simple query."""
        try:
            return await self.fetchval("SELECT 1") == 1
        except (
            asyncpg.PostgresError,
            ConnectionError,
            RuntimeError,
            ValueError,
            TimeoutError,
        ):
            return False


DB = Database(dsn=DBConfigs.CONNECTION_STRING)
"""Application-wide database wrapper used by the FastAPI backend."""

__all__ = ["DB", "Database"]
