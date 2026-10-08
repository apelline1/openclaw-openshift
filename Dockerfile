# ─────────────────────────────────────────────────────────────────────────────
# OpenClaw Gateway — Red Hat UBI 10 + Node.js 24
#
# Runs without elevated privileges on OpenShift (restricted-v2 SCC,
# UID 1000, read-only root FS).
# ─────────────────────────────────────────────────────────────────────────────
FROM registry.access.redhat.com/ubi10/nodejs-24:latest

# Do NOT set USER here — OpenShift injects a UID from the namespace's
# allowed range (e.g. 1002050000) at runtime via the restricted-v2 SCC.

# Data dir — must match the PVC mountPath in the Deployment manifest
ENV OPENCLAW_DATA_DIR=/data
# Bind to all interfaces so the ClusterIP Service can reach the pod
ENV OPENCLAW_BIND=0.0.0.0
ENV OPENCLAW_PORT=18789

# Install OpenClaw globally from npm
RUN npm install -g openclaw@latest --no-fund --no-audit

EXPOSE 18789

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -sf http://localhost:18789/api/health || exit 1

# "run" starts the gateway in the foreground (correct for containers).
# "--bind lan" exposes it on all interfaces so the K8s Service can reach it.
CMD ["openclaw", "gateway", "run", "--bind", "lan"]
