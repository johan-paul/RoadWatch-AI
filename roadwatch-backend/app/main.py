import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.database import engine
from app.models.models import Base

# Routers
from app.routers.auth import router as auth_router
from app.routers.complaints import router as complaints_router
from app.routers.officer import router as officer_router
from app.routers.citizen import router as citizen_router
from app.routers.admin import router as admin_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──────────────────────────────────────────────
    logger.info("Starting RoadWatch AI backend…")

    # Create tables if they don't exist (use Alembic in production)
    if settings.APP_ENV == "development":
        try:
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            logger.info("Database tables synced (dev mode).")
        except Exception as e:
            logger.warning(f"DB table sync skipped (connection issue at startup): {e}")
            logger.warning("Tables must already exist — server will continue starting up.")

    # Warm up Firebase
    try:
        from app.services.firebase_service import get_firebase_app
        get_firebase_app()
    except Exception as e:
        logger.warning(f"Firebase init warning: {e}")

    # ── Load AI model ─────────────────────────────────────────
    from app.services.ai_service import load_model, is_model_loaded, analyze_road_damage
    model_loaded = load_model(settings.AI_MODEL_PATH)
    if model_loaded:
        logger.info(f"✓ AI model loaded from {settings.AI_MODEL_PATH}")
        # ── Warmup: run one dummy inference to JIT-compile the model graph ──
        # This ensures the first real complaint doesn't hit a 30-90s cold start.
        try:
            import io
            import numpy as np
            from PIL import Image
            buf = io.BytesIO()
            Image.fromarray(np.zeros((224, 224, 3), dtype=np.uint8)).save(buf, format="JPEG")
            analyze_road_damage(buf.getvalue())
            logger.info("✓ AI model warmed up — first inference ready.")
        except Exception as e:
            logger.warning(f"Model warmup skipped: {e}")
    else:
        logger.warning(
            f"⚠ AI model not loaded (path: {settings.AI_MODEL_PATH}). "
            "Complaints will use default severity until the model is trained."
        )

    yield

    # ── Shutdown ─────────────────────────────────────────────
    await engine.dispose()
    logger.info("Database connections closed.")


app = FastAPI(
    title=settings.APP_NAME,
    description="AI-powered road hazard monitoring and civic management platform.",
    version="2.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.APP_ENV != "production" else None,
    redoc_url="/redoc" if settings.APP_ENV != "production" else None,
)

# ── CORS ──────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Global exception handler ──────────────────────────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception on {request.method} {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An internal error occurred. Please try again."},
    )

# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(auth_router,       prefix="/api/v1")
app.include_router(citizen_router,    prefix="/api/v1")
app.include_router(officer_router,    prefix="/api/v1")
app.include_router(complaints_router, prefix="/api/v1")
app.include_router(admin_router,      prefix="/api/v1")

# ── Health check ──────────────────────────────────────────────────────────────

@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok", "app": settings.APP_NAME, "version": "2.0.0"}
