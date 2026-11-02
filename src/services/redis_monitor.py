"""Monitor and restore connectivity to the Redis session store."""

import asyncio

from redis.exceptions import RedisError

from ..logging import get_logger
from ..redis import RedisWrapper

logger = get_logger()


class RedisMonitor:
    """Periodically check Redis and reconnect when the connection is unavailable."""

    def __init__(
        self,
        redis: RedisWrapper,
        *,
        check_interval: float = 10.0,
        retry_delay: float = 5.0,
    ) -> None:
        if check_interval <= 0:
            raise ValueError("check_interval must be greater than 0.")
        if retry_delay <= 0:
            raise ValueError("retry_delay must be greater than 0.")

        self._redis = redis
        self._check_interval = check_interval
        self._retry_delay = retry_delay

    async def start(self) -> None:
        """Check Redis connectivity continuously and reconnect after outages."""
        logger.info(
            "Redis health monitor started (check_interval=%ss).",
            self._check_interval,
        )
        while True:
            if not await self._redis.check_health():
                await self._attempt_reconnects()
            await asyncio.sleep(self._check_interval)

    async def wait_for_connection(self) -> None:
        """Wait indefinitely until Redis accepts a connection."""
        logger.info("Waiting for Redis session store.")
        await self._attempt_reconnects()

    async def _attempt_reconnects(self) -> None:
        attempt = 0
        while True:
            attempt += 1
            try:
                await self._redis.reconnect()
                return
            except asyncio.CancelledError:
                raise
            except (ConnectionError, OSError, RedisError, TimeoutError) as error:
                logger.warning(
                    "Redis reconnect attempt %s failed; retrying in %s seconds. "
                    "Error: %s",
                    attempt,
                    self._retry_delay,
                    error,
                )
                await asyncio.sleep(self._retry_delay)


__all__ = ["RedisMonitor"]
