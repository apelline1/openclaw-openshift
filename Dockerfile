# ─────────────────────────────────────────────────────────────────────────────
# OpenClaw Gateway — built on the official slim image
#
# Using the official image as base avoids a root-privilege npm install and
# ensures the OpenClaw version used at build time matches the one in the
# manifests. Add any site-specific customisations below the FROM line.
# ─────────────────────────────────────────────────────────────────────────────
FROM ghcr.io/openclaw/openclaw:slim

# Data dir — must match the PVC mountPath in the Deployment manifest.
# HOME must also point to the PVC so ~/.openclaw/ resolves to a writable path
# (OpenShift assigns a dynamic UID with no /etc/passwd entry).
ENV OPENCLAW_DATA_DIR=/data \
    OPENCLAW_BIND=lan \
    OPENCLAW_PORT=18789 \
    HOME=/data

EXPOSE 18789

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -sf http://localhost:18789/healthz || exit 1

# "run" starts the gateway in the foreground (required in containers).
# "--bind lan" exposes it on all interfaces so the K8s Service can reach it.
# "--allow-unconfigured" lets the gateway start before onboarding completes.
CMD ["openclaw", "gateway", "run", "--bind", "lan", "--allow-unconfigured"]
