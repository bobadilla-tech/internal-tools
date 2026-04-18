import glob
import os

# Remove stale pyc so the patched .py is recompiled
for pyc in glob.glob("/app/backend/plane/settings/__pycache__/production.*.pyc"):
    os.unlink(pyc)

patch = """
EMAIL_HOST = os.environ.get("EMAIL_HOST", "localhost")
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", 25))
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = os.environ.get("EMAIL_USE_TLS", "0") == "1"
EMAIL_USE_SSL = os.environ.get("EMAIL_USE_SSL", "0") == "1"
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "noreply@localhost")
SERVER_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "noreply@localhost")
"""

settings_path = "/app/backend/plane/settings/production.py"
with open(settings_path) as f:
    content = f.read()

if "EMAIL_HOST = os.environ" not in content:
    with open(settings_path, "a") as f:
        f.write(patch)
