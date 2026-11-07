"""
* Project Name: BONDVAULT PK

* Description: Background monitoring and recovery for the PostgreSQL connection.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-24 10:20:00

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-24 10:20:02

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

import asyncio

import asyncpg

from .. import configs
from ..database import Database
from ..logging import get_logger

logger = get_logger()


class DatabaseMonitor:
    """Continuously check the database and recover it when connectivity fails.

    Recovery is intentionally direct: the monitor attempts to rebuild the database pool and retry the connection PostgreSQL."""

    def __init__(
        self,
        database: Database,
        *,
        check_interval: float = 10.0,
        retry_delay: float = 5.0,
    ) -> None:
        if check_interval <= 0:
            raise ValueError("check_interval must be greater than 0.")
        if retry_delay <= 0:
            raise ValueError("retry_delay must be greater than 0.")

        self._database = database
        self._check_interval = check_interval
        self._retry_delay = retry_delay
        self._outage_reported = False

    async def start(self) -> None:
        """Starts the Databse Monitor."""

        logger.info(
            "PostgreSQL health monitor started (check_interval=%ss).",
            self._check_interval,
        )

        while True:
            try:
                is_healthy = await self._database.check_health()
            except asyncio.CancelledError:
                raise
            except (
                ConnectionError,
                RuntimeError,
                asyncpg.exceptions.PostgresError,
                asyncpg.exceptions.InterfaceError,
            ):
                is_healthy = False

            if not is_healthy:
                await self._attempt_reconnects("runtime")

            await asyncio.sleep(self._check_interval)

    async def wait_for_connection(self) -> None:
        """Wait indefinitely until the database accepts a connection."""

        logger.info(
            "Waiting for PostgreSQL (host=%s, port=%s, database=%s).",
            configs.DBConfigs.POSTGRES_HOST,
            configs.DBConfigs.POSTGRES_PORT,
            configs.DBConfigs.POSTGRES_DB,
        )
        await self._attempt_reconnects("startup")

    async def _attempt_reconnects(self, phase: str) -> bool:
        """Keep replacing the database connection until it's healthy or timed out."""

        attempt = 0

        while True:
            attempt += 1
            try:
                await self._database.reconnect()
                is_healthy = await self._database.check_health()
                failure: Exception | None = None
            except asyncio.CancelledError:
                raise
            except (
                ConnectionError,
                RuntimeError,
                asyncpg.exceptions.PostgresError,
                asyncpg.exceptions.InterfaceError,
            ) as error:
                is_healthy = False
                failure = error

            if is_healthy:
                self._outage_reported = False
                if phase == "startup":
                    logger.success(
                        "PostgreSQL connection ready (host=%s, port=%s, database=%s).",
                        configs.DBConfigs.POSTGRES_HOST,
                        configs.DBConfigs.POSTGRES_PORT,
                        configs.DBConfigs.POSTGRES_DB,
                    )
                else:
                    logger.success(
                        "PostgreSQL connection restored (host=%s, port=%s, database=%s).",
                        configs.DBConfigs.POSTGRES_HOST,
                        configs.DBConfigs.POSTGRES_PORT,
                        configs.DBConfigs.POSTGRES_DB,
                    )
                return True

            if not self._outage_reported:
                logger.warning(
                    "PostgreSQL %s attempt %s failed; retrying in %s seconds "
                    "(host=%s, port=%s, database=%s).%s",
                    "connection" if phase == "startup" else "reconnect",
                    attempt,
                    self._retry_delay,
                    configs.DBConfigs.POSTGRES_HOST,
                    configs.DBConfigs.POSTGRES_PORT,
                    configs.DBConfigs.POSTGRES_DB,
                    (
                        f" Error: {failure.__cause__ or failure}"
                        if failure is not None
                        else ""
                    ),
                )
                self._outage_reported = True

            await asyncio.sleep(self._retry_delay)
