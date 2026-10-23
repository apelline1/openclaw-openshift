# ─────────────────────────────────────────────────────────────────────────────
# OpenClaw Gateway — Red Hat UBI 10 + Node.js 24
#
# Uses the Red Hat Universal Base Image (UBI) for supply-chain compliance.
# npm install runs as root so it can write to the global prefix, then we
# drop back to a non-root user. OpenShift overrides the UID at runtime
# with a value from the namespace's allowed range (restricted-v2 SCC).
# ─────────────────────────────────────────────────────────────────────────────
FROM registry.access.redhat.com/ubi10/nodejs-24:latest

# Temporarily become root to install into the global npm prefix
USER root

RUN npm install -g openclaw@latest --no-fund --no-audit && \
    # Clean npm cache to keep the image lean
    npm cache clean --force

# Drop back to the UBI default non-root user (1000).
# OpenShift will override this with a namespace-scoped UID at runtime.
USER 1000

# Data dir — must match the PVC mountPath in the Deployment manifest.
# HOME must point to the PVC so ~/.openclaw/ resolves to a writable path
# (OpenShift assigns a dynamic UID with no /etc/passwd entry).
ENV OPENCLAW_DATA_DIR=/data \
    OPENCLAW_BIND=lan \
    OPENCLAW_PORT=18789 \
    HOME=/data

EXPOSE 18789

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -sf http://localhost:18789/healthz || exit 1

# "run" starts the gateway in the foreground (required in containers).
# "--bind lan" exposes on all interfaces so the K8s Service can reach it.
# "--allow-unconfigured" lets the gateway start before onboarding completes.
CMD ["openclaw", "gateway", "run", "--bind", "lan", "--allow-unconfigured"]
