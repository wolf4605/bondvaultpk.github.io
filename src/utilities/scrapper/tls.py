"""TLS configuration shared by prize-bond source clients."""

import ssl

import certifi


def create_scraper_ssl_context() -> ssl.SSLContext:
    """Create a verified TLS context using certifi's maintained CA bundle."""
    context = ssl.create_default_context(cafile=certifi.where())
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    return context
