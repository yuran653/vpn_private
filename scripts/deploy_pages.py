"""Deploy dist/ to Cloudflare Pages arch-casedigestai."""
import ssl
import certifi
import json
import os
from make_cloudflare import pages

# Load env variables safely without printing secrets
env = {}
with open(".env") as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()

account_id = env.get("CF_ACCOUNT_ID")
token = env.get("CF_API_TOKEN")
project_name = "arch-casedigestai"

print(f"Deploying dist/ to Cloudflare Pages project: {project_name}...")
result = pages.deploy("dist", project=project_name, account=account_id, token=token)
print("Deployment completed successfully!")
print("Result URL:", result.get("url") if isinstance(result, dict) else result)
