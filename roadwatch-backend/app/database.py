import socket
import ssl as _ssl
from urllib.parse import urlparse

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings


def _ipv4_engine_args(database_url: str) -> tuple[str, dict]:
    """
    Mobile hotspots frequently block IPv6 to port 5432.
    This function resolves the DB hostname to its IPv4 address at startup
    so asyncpg never even tries IPv6.

    Falls back to the original URL transparently if DNS fails.
    """
    try:
        parsed   = urlparse(database_url)
        hostname = parsed.hostname
        port     = parsed.port or 5432

        # AF_INET = IPv4 only
        addrs = socket.getaddrinfo(hostname, port, socket.AF_INET, socket.SOCK_STREAM)
        if not addrs:
            return database_url, {}

        ipv4 = addrs[0][4][0]

        # Replace hostname with IPv4 in the URL
        ipv4_url = database_url.replace(f"@{hostname}:{port}", f"@{ipv4}:{port}", 1)
        # Handle the case where port isn't explicit in the URL
        if ipv4_url == database_url:
            ipv4_url = database_url.replace(f"@{hostname}/", f"@{ipv4}/", 1)

        # When connecting to a raw IP address the TLS library won't find a
        # hostname match in the certificate. We keep SSL on (required by
        # Supabase) but disable hostname verification — cert is still validated
        # against the system CA store, so the channel stays encrypted.
        ssl_ctx = _ssl.create_default_context()
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode    = _ssl.CERT_REQUIRED

        return ipv4_url, {"ssl": ssl_ctx}

    except Exception:
        # Any failure (no network, DNS error, etc.) — use original URL as-is
        return database_url, {}


_db_url, _connect_args = _ipv4_engine_args(settings.DATABASE_URL)

engine = create_async_engine(
    _db_url,
    echo=settings.APP_ENV == "development",
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    connect_args=_connect_args,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
