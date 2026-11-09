"""Email delivery and account-action notification messages."""

from email.message import EmailMessage
from importlib.resources import files
from string import Template

import aiosmtplib
from pydantic import EmailStr, ValidationError

from ..configs.email_settings import _EmailConfigs

ADMIN_INVITE_EXPIRY_HOURS = 24


class EmailDeliveryError(RuntimeError):
    """SMTP is missing, misconfigured, or failed to deliver an email."""


def _render_mail_template(
    template_name: str,
    values: dict[str, str],
) -> tuple[str, str]:
    """Load a text template whose first line is its subject."""
    template = (
        files("src.mail_templates")
        .joinpath(f"{template_name}.txt")
        .read_text(encoding="utf-8")
        .replace("\r\n", "\n")
    )
    subject_line, separator, body_template = template.partition("\n\n")
    if not separator or not subject_line.startswith("Subject: "):
        raise ValueError(f"Invalid email template format: {template_name}")

    subject = Template(subject_line.removeprefix("Subject: ")).substitute(values)
    body = Template(body_template).substitute(values)
    return subject, body


async def send_email(recipient: EmailStr, subject: str, body: str) -> None:
    """Send a plain-text email using the configured SMTP account."""
    try:
        settings = _EmailConfigs()
    except ValidationError as error:
        raise EmailDeliveryError(
            "SMTP configuration is invalid. Set SMTP_Server to a hostname "
            "such as smtp.gmail.com and SMTP_Port to 587 or 465."
        ) from error

    if (
        settings.SMTP_Server is None
        or settings.SMTP_Port is None
        or settings.Email is None
        or settings.Password is None
    ):
        raise EmailDeliveryError(
            "SMTP_Server, SMTP_Port, Email, and Password must be configured "
            "before sending email."
        )

    message = EmailMessage()
    message["From"] = str(settings.Email)
    message["To"] = str(recipient)
    message["Subject"] = subject
    message.set_content(body)

    try:
        await aiosmtplib.send(
            message,
            hostname=settings.SMTP_Server,
            port=settings.SMTP_Port,
            username=str(settings.Email),
            password=settings.Password.get_secret_value(),
            use_tls=settings.SMTP_Port == 465,
            start_tls=settings.SMTP_Port != 465,
        )
    except (aiosmtplib.SMTPException, OSError) as error:
        raise EmailDeliveryError(
            "Email delivery failed. Check the SMTP hostname, port, TLS mode, "
            "network access, and account credentials."
        ) from error


async def send_admin_invitation_email(
    recipient: EmailStr,
    username: str,
    token: str,
) -> None:
    """Send a one-time account activation token, never a reusable password."""
    subject, body = _render_mail_template(
        "admin_invitation",
        {
            "username": username,
            "email": str(recipient),
            "token": token,
            "expiry_hours": str(ADMIN_INVITE_EXPIRY_HOURS),
        },
    )
    await send_email(
        recipient,
        subject,
        body,
    )


async def send_user_action_email(
    recipient: EmailStr,
    username: str,
    action: str,
    details: str,
) -> None:
    """Notify a user that an administrator changed their account status."""
    subject, body = _render_mail_template(
        "user_action",
        {
            "username": username,
            "action": action,
            "details": details,
        },
    )
    await send_email(recipient, subject, body)


async def send_market_listing_removed_email(
    recipient: EmailStr,
    username: str,
    listing_title: str,
    reason: str,
) -> None:
    """Notify a user that an administrator removed their listing and explain why."""
    subject, body = _render_mail_template(
        "market_listing_removed",
        {
            "username": username,
            "listing_title": listing_title,
            "reason": reason,
        },
    )
    await send_email(recipient, subject, body)


async def send_verification_code_email(recipient: EmailStr, code: str) -> None:
    """Email a short-lived verification code without exposing it in the API."""
    subject, body = _render_mail_template(
        "email_verification",
        {"code": code},
    )
    await send_email(recipient, subject, body)


async def send_password_recovery_email(recipient: EmailStr, code: str) -> None:
    """Send a short-lived password recovery code."""
    subject, body = _render_mail_template(
        "password_recovery",
        {"code": code},
    )
    await send_email(recipient, subject, body)
