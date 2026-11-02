"""Application wrapper around Redis connection and session operations."""

from typing import Literal
from uuid import UUID

from redis.asyncio import Redis
from redis.exceptions import RedisError

from ..configs.redis_configs import get_redis_url
from ..logging import get_logger

logger = get_logger()


class RedisWrapper:
    """Own a Redis connection and expose session-oriented operations."""

    def __init__(self) -> None:
        self._client: Redis | None = None
        self._has_connected = False

    async def connect(self) -> None:
        """Connect to Redis and fail startup if the session store is unavailable."""
        if self._client is not None:
            return

        redis_url = get_redis_url()
        client = Redis.from_url(redis_url, decode_responses=True)
        connection = client.connection_pool.connection_kwargs
        host = connection.get("host", "localhost")
        port = connection.get("port", 6379)
        database = connection.get("db", 0)
        logger.info(
            "Connecting to Redis session store (host=%s, port=%s, database=%s).",
            host,
            port,
            database,
        )
        try:
            await client.ping()
        except Exception as error:
            await client.aclose()
            logger.warning(
                "Redis session store connection failed (host=%s, port=%s, database=%s): %s",
                host,
                port,
                database,
                error,
            )
            raise ConnectionError("Unable to connect to Redis.") from error

        self._client = client
        if self._has_connected:
            logger.success(
                "Redis session store connection restored (host=%s, port=%s, database=%s).",
                host,
                port,
                database,
            )
        else:
            logger.success(
                "Redis session store connected (host=%s, port=%s, database=%s).",
                host,
                port,
                database,
            )
        self._has_connected = True

    async def close(self) -> None:
        """Close the Redis connection pool."""
        if self._client is None:
            return

        client = self._client
        self._client = None
        await client.aclose()
        logger.info("Redis session store connection closed.")

    async def reconnect(self) -> None:
        """Recreate the Redis client after a connection failure."""
        if self._client is not None:
            await self.close()
        await self.connect()

    async def check_health(self) -> bool:
        """Check whether Redis responds to a ping."""
        try:
            return bool(await self._require_client().ping())
        except (ConnectionError, RedisError, OSError, TimeoutError) as error:
            logger.warning("Redis session store health check failed: %s", error)
            return False

    def _require_client(self) -> Redis:
        if self._client is None:
            raise ConnectionError("The Redis session store is not initialized.")
        return self._client

    @staticmethod
    def _session_key(session_id: UUID) -> str:
        return f"auth:session:{session_id}"

    @staticmethod
    def _account_sessions_key(
        subject: UUID,
        role: Literal["user", "admin"],
    ) -> str:
        return f"auth:sessions:{role}:{subject}"

    @staticmethod
    def _session_value(
        subject: UUID,
        role: Literal["user", "admin"],
    ) -> str:
        return f"{role}:{subject}"

    @staticmethod
    def _as_text(value: str | bytes | None) -> str | None:
        if isinstance(value, bytes):
            return value.decode("ascii")
        return value

    async def create_session(
        self,
        subject: UUID,
        role: Literal["user", "admin"],
        session_id: UUID,
        lifetime_seconds: int,
    ) -> None:
        """Create a session record and add it to the account's session index."""
        client = self._require_client()
        session_key = self._session_key(session_id)
        sessions_key = self._account_sessions_key(subject, role)
        async with client.pipeline(transaction=True) as pipeline:
            pipeline.set(
                session_key,
                self._session_value(subject, role),
                ex=lifetime_seconds,
            )
            pipeline.sadd(sessions_key, str(session_id))
            pipeline.expire(sessions_key, lifetime_seconds)
            await pipeline.execute()

    async def refresh_session(
        self,
        subject: UUID,
        role: Literal["user", "admin"],
        session_id: UUID,
        lifetime_seconds: int,
    ) -> bool:
        """Extend an active session only if its Redis record is still valid."""
        script = """
        if redis.call("GET", KEYS[1]) ~= ARGV[1] then
            return 0
        end
        redis.call("EXPIRE", KEYS[1], ARGV[2])
        redis.call("SADD", KEYS[2], ARGV[3])
        redis.call("EXPIRE", KEYS[2], ARGV[2])
        return 1
        """
        result = await self._require_client().eval(
            script,
            2,
            self._session_key(session_id),
            self._account_sessions_key(subject, role),
            self._session_value(subject, role),
            lifetime_seconds,
            str(session_id),
        )
        return result == 1

    async def revoke_session(
        self,
        subject: UUID,
        role: Literal["user", "admin"],
        session_id: UUID,
    ) -> None:
        """Revoke one session and remove its account-index entry."""
        script = """
        redis.call("DEL", KEYS[1])
        redis.call("SREM", KEYS[2], ARGV[1])
        if redis.call("SCARD", KEYS[2]) == 0 then
            redis.call("DEL", KEYS[2])
        end
        return 1
        """
        await self._require_client().eval(
            script,
            2,
            self._session_key(session_id),
            self._account_sessions_key(subject, role),
            str(session_id),
        )

    async def revoke_account_sessions(
        self,
        subject: UUID,
        role: Literal["user", "admin"],
    ) -> None:
        """Revoke every session associated with an account."""
        script = """
        local sessions = redis.call("SMEMBERS", KEYS[1])
        for _, session_id in ipairs(sessions) do
            redis.call("DEL", ARGV[1] .. session_id)
        end
        redis.call("DEL", KEYS[1])
        return #sessions
        """
        await self._require_client().eval(
            script,
            1,
            self._account_sessions_key(subject, role),
            "auth:session:",
        )

    async def get_active_user_ids(self) -> set[UUID]:
        """Return user IDs whose Redis session indexes contain a live session."""
        client = self._require_client()
        active_user_ids: set[UUID] = set()
        async for sessions_key in client.scan_iter(match="auth:sessions:user:*"):
            subject_id = UUID(sessions_key.rsplit(":", maxsplit=1)[-1])
            session_ids = {
                session_id
                for raw_session_id in await client.smembers(sessions_key)
                if (session_id := self._as_text(raw_session_id)) is not None
            }
            if not session_ids:
                await client.delete(sessions_key)
                continue

            session_ids_list = list(session_ids)
            session_keys = [
                self._session_key(UUID(session_id))
                for session_id in session_ids_list
            ]
            session_values = await client.mget(session_keys)
            expected_value = f"user:{subject_id}"
            active_session_ids = [
                session_id
                for session_id, value in zip(
                    session_ids_list,
                    session_values,
                    strict=True,
                )
                if self._as_text(value) == expected_value
            ]
            if active_session_ids:
                active_user_ids.add(subject_id)
                stale_session_ids = set(session_ids) - set(active_session_ids)
                if stale_session_ids:
                    await client.srem(sessions_key, *stale_session_ids)
            else:
                await client.delete(sessions_key)

        return active_user_ids


__all__ = ["RedisWrapper"]
