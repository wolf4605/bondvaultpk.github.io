"""
* Project Name: BONDVAULT PK

* Description: The sequence of automated event(s) that are to run in the background while the backend is running.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 09:20:06

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 09:21:14

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from ..configs import AdminDBConfigs, AppSettings
from ..database import DB
from ..logging import get_logger, setup_logging
from ..utilities.auth_tokens import validate_jwt_config
from .db_initializor import DB_initializor
from .db_monitor import DatabaseMonitor


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    """Configure logging and manage the shared database connection pool."""

    # Actions to perform when API starts
    # 1. Setup logging
    setup_logging()
    logger = get_logger()
    logger.info("Logging System Configured.")

    if AppSettings.Initialize_Database is True:
        if not AdminDBConfigs.ADMIN_POSTGRES_USER or not AdminDBConfigs.ADMIN_POSTGRES_PASSWORD:
            logger.warning("You have asked for initialization of database but have not provided [cyan]ADMIN_POSTGRES_USER[/] or [cyan]ADMIN_POSTGRES_PASSWORD[/] in .env file." )
         
        else:
            await DB_initializor().start()
            logger.info("Database initialized now you can remove [cyan]ADMIN_POSTGRES_USER[/] or [cyan]ADMIN_POSTGrES_PASSWORD[/] from .env file.")

    monitor_task: asyncio.Task[None] | None = None
    try:
        logger.debug("Connecting to the database...")
        monitor: DatabaseMonitor = DatabaseMonitor(DB)
        await monitor.wait_for_connection()
        monitor_task = asyncio.create_task(
            monitor.start(), name="Database-Health-Monitor"
        )
        validate_jwt_config()

        yield

    finally:
        if monitor_task is not None:
            if not monitor_task.done():
                monitor_task.cancel()

            await asyncio.gather(monitor_task, return_exceptions=True)

        await DB.pool_close()
        logger.success("Connection Pool closed successfully.")
