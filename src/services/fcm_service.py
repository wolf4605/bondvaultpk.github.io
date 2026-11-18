"""Push notification delivery service using Firebase Admin SDK."""

import logging
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, messaging

logger = logging.getLogger("application.audit")

# Path to firebase-service-account.json inside src/configs/
_SERVICE_ACCOUNT_PATH = (
    Path(__file__).resolve().parent.parent / "configs" / "firebase-service-account.json"
)

# Initialize Firebase Admin SDK if key file exists and app is not yet initialized
if not firebase_admin._apps and _SERVICE_ACCOUNT_PATH.exists():
    try:
        cred = credentials.Certificate(str(_SERVICE_ACCOUNT_PATH))
        firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin SDK initialized successfully.")
    except Exception as _err:
        logger.warning(f"Failed to initialize Firebase Admin SDK: {_err}")


async def send_fcm_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> bool:
    """Send a high-priority FCM push notification directly to user's mobile device."""
    if not fcm_token or not fcm_token.strip():
        return False

    if not firebase_admin._apps:
        logger.info(
            f"FCM push notification queued for device token {fcm_token[:12]}... ('{title}')"
        )
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=fcm_token.strip(),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="bondvault_user_reports_channel",
                    sound="default",
                ),
            ),
        )
        response = messaging.send(message)
        logger.info(f"FCM push notification dispatched successfully: {response}")
        return True
    except Exception as error:
        logger.warning(f"FCM push notification dispatch failed: {error}")

    return False
