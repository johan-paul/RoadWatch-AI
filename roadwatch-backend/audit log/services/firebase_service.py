import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from app.config import settings
import logging

logger = logging.getLogger(__name__)

_firebase_app = None


def get_firebase_app():
    global _firebase_app
    if _firebase_app is None:
        try:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized")
        except Exception as e:
            logger.error(f"Firebase init error: {e}")
            raise
    return _firebase_app


async def verify_firebase_token(id_token: str) -> dict:
    """
    Verify Firebase ID token from the mobile app.
    Returns decoded token dict with phone_number and uid.
    Raises ValueError if invalid.
    """
    try:
        get_firebase_app()
        decoded = firebase_auth.verify_id_token(id_token)

        phone = decoded.get("phone_number")
        if not phone:
            raise ValueError("Firebase token does not contain a phone number. "
                             "Ensure phone auth was used, not email/password.")

        return {
            "uid": decoded["uid"],
            "phone_number": phone,
            "firebase_uid": decoded["uid"],
        }
    except firebase_auth.ExpiredIdTokenError:
        raise ValueError("Firebase token has expired. Please re-authenticate.")
    except firebase_auth.InvalidIdTokenError:
        raise ValueError("Invalid Firebase token.")
    except firebase_auth.RevokedIdTokenError:
        raise ValueError("Firebase token has been revoked.")
    except Exception as e:
        logger.error(f"Firebase token verification failed: {e}")
        raise ValueError(f"Token verification failed: {str(e)}")
