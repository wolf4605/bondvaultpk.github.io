
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
            raise ValueError(
                "check_interval must be greater than 0."
            )

        if retry_delay <= 0:
            raise ValueError(
                "retry_delay must be greater than 0."
            )

        self._redis = redis
        self._check_interval = check_interval
        self._retry_delay = retry_delay
        self._outage_reported = False

    async def start(self) -> None:
        """Continuously monitor Redis and restore connectivity when necessary."""

        logger.info(
            "Redis health monitor started "
            "(check_interval=%ss, retry_delay=%ss).",
            self._check_interval,
            self._retry_delay,
        )

        while True:
            try:
                is_healthy = await self._redis.check_health()

                if not is_healthy:
                    logger.warning(
                        "Redis session store is unavailable. "
                        "Attempting to reconnect."
                    )

                    await self._attempt_reconnects()

            except asyncio.CancelledError:
                raise

            except (
                ConnectionError,
                OSError,
                RedisError,
                TimeoutError,
            ) as error:
                logger.warning(
                    "Redis health check failed: %s",
                    error.__cause__ or error,
                )

                await self._attempt_reconnects()

            await asyncio.sleep(self._check_interval)

    async def wait_for_connection(self) -> None:
        """Wait indefinitely until Redis accepts a connection."""

        logger.info(
            "Waiting for Redis session store connection."
        )

        await self._attempt_reconnects()

    async def _attempt_reconnects(self) -> None:
        """Retry Redis connection until a connection is established."""

        attempt = 0

        while True:
            attempt += 1

            try:
                await self._redis.reconnect()

                if self._outage_reported:
                    logger.success(
                        "Redis session store is available again."
                    )

                self._outage_reported = False

                return

            except asyncio.CancelledError:
                raise

            except (
                ConnectionError,
                OSError,
                RedisError,
                TimeoutError,
            ) as error:
                if not self._outage_reported:
                    logger.warning(
                        "Redis reconnect attempt %s failed. "
                        "Retrying in %s seconds. Error: %s",
                        attempt,
                        self._retry_delay,
                        error.__cause__ or error,
                    )

                    self._outage_reported = True

                await asyncio.sleep(self._retry_delay)


__all__ = ["RedisMonitor"]
