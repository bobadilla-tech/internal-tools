import os

patch = """
EMAIL_HOST = os.environ.get("EMAIL_HOST", "localhost")
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", 25))
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = os.environ.get("EMAIL_USE_TLS", "False").lower() in ("true", "1")
EMAIL_USE_SSL = os.environ.get("EMAIL_USE_SSL", "False").lower() in ("true", "1")
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "noreply@localhost")
SERVER_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "noreply@localhost")
"""

settings_path = "/app/backend/plane/settings/production.py"
with open(settings_path) as f:
    content = f.read()

if "EMAIL_HOST = os.environ" not in content:
    with open(settings_path, "a") as f:
        f.write(patch)
