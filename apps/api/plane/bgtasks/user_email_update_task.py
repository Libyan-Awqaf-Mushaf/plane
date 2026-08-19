# Copyright (c) 2023-present Plane Software, Inc. and contributors
# SPDX-License-Identifier: AGPL-3.0-only
# See the LICENSE file for details.

# Python imports
import logging

# Third party imports
from celery import shared_task

# Django imports
from django.core.mail import EmailMultiAlternatives, get_connection
from django.template.loader import render_to_string

# Module imports
from plane.license.utils.instance_value import get_email_configuration
from plane.utils.email import generate_plain_text_from_html
from plane.utils.exception_logger import log_exception


@shared_task
def send_email_update_magic_code(email, token):
    try:
        (
            EMAIL_HOST,
            EMAIL_HOST_USER,
            EMAIL_HOST_PASSWORD,
            EMAIL_PORT,
            EMAIL_USE_TLS,
            EMAIL_USE_SSL,
            EMAIL_FROM,
        ) = get_email_configuration()

        # Send the mail
        from plane.db.models import User, Profile
        user = User.objects.filter(email=email).first()
        language = "en"
        if user:
            profile = Profile.objects.filter(user=user).first()
            if profile:
                language = profile.language

        if language == "ar":
            subject = "تحقق من عنوان بريدك الإلكتروني الجديد"
            template_name = "emails/auth/magic_signin_ar.html"
        else:
            subject = "Verify your new email address"
            template_name = "emails/auth/magic_signin.html"

        context = {"code": token, "email": email}

        html_content = render_to_string(template_name, context)
        text_content = generate_plain_text_from_html(html_content)

        connection = get_connection(
            host=EMAIL_HOST,
            port=int(EMAIL_PORT),
            username=EMAIL_HOST_USER,
            password=EMAIL_HOST_PASSWORD,
            use_tls=EMAIL_USE_TLS == "1",
            use_ssl=EMAIL_USE_SSL == "1",
        )

        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=EMAIL_FROM,
            to=[email],
            connection=connection,
        )
        msg.attach_alternative(html_content, "text/html")
        msg.send()
        logging.getLogger("plane.worker").info("Email sent successfully.")
        return
    except Exception as e:
        log_exception(e)
        return


@shared_task
def send_email_update_confirmation(email):
    """
    Send a confirmation email to the user after their email address has been successfully updated.

    Args:
        email: The new email address that was successfully updated
    """
    try:
        (
            EMAIL_HOST,
            EMAIL_HOST_USER,
            EMAIL_HOST_PASSWORD,
            EMAIL_PORT,
            EMAIL_USE_TLS,
            EMAIL_USE_SSL,
            EMAIL_FROM,
        ) = get_email_configuration()

        # Send the confirmation email
        from plane.db.models import User, Profile
        user = User.objects.filter(email=email).first()
        language = "en"
        if user:
            profile = Profile.objects.filter(user=user).first()
            if profile:
                language = profile.language

        if language == "ar":
            subject = "تم تحديث عنوان بريد Plane الإلكتروني بنجاح"
            template_name = "emails/user/email_updated_ar.html"
        else:
            subject = "Plane email address successfully updated"
            template_name = "emails/user/email_updated.html"

        context = {"email": email}

        html_content = render_to_string(template_name, context)
        text_content = generate_plain_text_from_html(html_content)

        connection = get_connection(
            host=EMAIL_HOST,
            port=int(EMAIL_PORT),
            username=EMAIL_HOST_USER,
            password=EMAIL_HOST_PASSWORD,
            use_tls=EMAIL_USE_TLS == "1",
            use_ssl=EMAIL_USE_SSL == "1",
        )

        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=EMAIL_FROM,
            to=[email],
            connection=connection,
        )
        msg.attach_alternative(html_content, "text/html")
        msg.send()
        logging.getLogger("plane.worker").info(f"Email update confirmation sent successfully to {email}.")
        return
    except Exception as e:
        log_exception(e)
        return
