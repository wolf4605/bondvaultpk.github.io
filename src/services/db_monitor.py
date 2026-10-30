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

    async def start(self) -> None:
        """Starts the Databse Monitor."""

        logger.info(
            "Database Monitor Started; Checking every [cyan]%s[/] seconds.",
            int(self._check_interval),
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
                logger.warning("Database Connection Lost.")
                is_healthy = False

            if not is_healthy:
                await self._attempt_reconnects("runtime")

            await asyncio.sleep(self._check_interval)

    async def wait_for_connection(self) -> None:
        """Wait indefinitely until the database accepts a connection."""

        await self._attempt_reconnects("startup")

    async def _attempt_reconnects(self, phase: str) -> bool:
        """Keep replacing the database connection until it's healthy or timed out."""

        has_reported: bool = False

        while True:
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
                if phase == "startup":
                    logger.success(
                        f"Database Connection Initialized.\n🌐 Host: [underline blue]{configs.DBConfigs.POSTGRES_HOST}:{configs.DBConfigs.POSTGRES_PORT}[/]\n👤 User: [blue]{configs.DBConfigs.POSTGRES_USER}[/]\n🗃️ DB Name: [blue]{configs.DBConfigs.POSTGRES_DB}[/]"
                    )
                else:
                    logger.success(
                        f"Database Connection Re-initialized.\n🌐 Host: [underline blue]{configs.DBConfigs.POSTGRES_HOST}:{configs.DBConfigs.POSTGRES_PORT}[/]\n👤 User: [blue]{configs.DBConfigs.POSTGRES_USER}[/]\n🗃️ DB Name: [blue]{configs.DBConfigs.POSTGRES_DB}[/]"
                    )
                return True

            if not has_reported:
                if phase == "startup":
                    logger.critical(
                        "Unable to connect the Database. Retrying...\nIs the Database Online?"
                    )
                else:
                    logger.critical(
                        "Connection to the Database Lost. Retrying...\nIs the Database Online?"
                    )

                has_reported = True

            if failure is not None:
                logger.debug("Database reconnect attempt failed: %s", failure)

            await asyncio.sleep(self._retry_delay)
