# OpenClaw on OpenShift 🦞

A simple [OpenClaw](https://openclaw.ai) AI chatbot gateway running on OpenShift,
deployed automatically from GitHub via GitHub Actions **or manually via the `oc` CLI**.

---

## Architecture

```
GitHub push → GitHub Actions → Build image (GHCR) → Deploy to OpenShift
                                                            │
                                                   ┌────────▼────────┐
                                                   │    OpenShift    │
                                                   │  ns: openclaw   │
                                                   │                 │
                                                   │  Deployment     │
                                                   │  Service        │
                                                   │  Route (TLS)    │
                                                   │  PVC (10 Gi)    │
                                                   └─────────────────┘
```

---

## Prerequisites

| What | How to get it |
|------|---------------|
| OpenShift cluster | ROSA, ARO, Developer Sandbox, or self-managed |
| `oc` CLI | `brew install openshift-cli` |
| OpenAI API key | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| GitHub account | To host this repo and run Actions |

---

## Option A — Deploy via `oc` CLI (manual)

Use this to deploy directly from your terminal without GitHub Actions.

### 1 — Log in to your cluster

```bash
oc login --server=https://api.your-cluster.example.com:6443
# or use the token-based login from the OpenShift web console:
# click your username → "Copy login command"
```

### 2 — Create the namespace

```bash
# namespace already exists — skip this step
# oc new-project openclaw
```

### 3 — Create the Secret (API keys)

```bash
# Generate a random gateway token
GATEWAY_TOKEN=$(openssl rand -hex 32)

oc create secret generic openclaw-secrets \
  --from-literal=gateway-token="${GATEWAY_TOKEN}" \
  --from-literal=openai-api-key="sk-..."          \   # ← paste your OpenAI key
  -n apelline-dev
```

### 4 — Apply all manifests

```bash
oc apply -k manifests/ --server-side
```

This creates in one command:
- `ServiceAccount`
- `PersistentVolumeClaim` (10 Gi)
- `ConfigMap` (openclaw.json + AGENTS.md)
- `Deployment`
- `Service`
- `Route` (TLS-terminated)

### 5 — Wait for the pod to be ready

```bash
oc rollout status deployment/openclaw -n apelline-dev --timeout=180s
```

### 6 — Open the chatbot dashboard

```bash
# Get the public URL
oc get route openclaw -n apelline-dev -o jsonpath='https://{.spec.host}{"\n"}'

# Or open it directly (macOS)
open "https://$(oc get route openclaw -n apelline-dev -o jsonpath='{.spec.host}')"
```

### Updating after a config change

```bash
# Edit manifests/configmap.yaml or manifests/deployment.yaml, then:
oc apply -k manifests/ --server-side
oc rollout restart deployment/openclaw -n apelline-dev
oc rollout status deployment/openclaw -n apelline-dev
```

### Tearing down

```bash
oc delete project openclaw
```

---

## Option B — Deploy via GitHub Actions (CI/CD, recommended)

Every push to `main` automatically builds the image and deploys to OpenShift.

### 1 — Create the Secret on your cluster (same as Step 3 above)

```bash
GATEWAY_TOKEN=$(openssl rand -hex 32)

oc create secret generic openclaw-secrets \
  --from-literal=gateway-token="${GATEWAY_TOKEN}" \
  --from-literal=openai-api-key="sk-..."          \
  -n apelline-dev
```

### 2 — Create a deploy service account and token

```bash
oc create sa github-deployer -n apelline-dev
oc adm policy add-role-to-user edit -z github-deployer -n apelline-dev

# Copy the output of this command — you'll need it in the next step
oc create token github-deployer -n apelline-dev --duration=8760h
```

### 3 — Add GitHub Secrets

In your GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Value |
|-------------|-------|
| `OPENSHIFT_SERVER` | `https://api.your-cluster.example.com:6443` |
| `OPENSHIFT_TOKEN` | Token from the previous step |

### 4 — Push to `main`

```bash
git push origin main
```

Watch the pipeline in the **Actions** tab. When it finishes, the bot is live.

---

## Useful `oc` commands (day-to-day)

```bash
# View live pod logs
oc logs -f deployment/openclaw -n apelline-dev

# Open a shell inside the running pod
oc rsh deployment/openclaw -n apelline-dev

# Check pod status
oc get pods -n apelline-dev

# Restart the gateway (e.g. after a config change)
oc rollout restart deployment/openclaw -n apelline-dev

# Scale down (pause the bot)
oc scale deployment/openclaw --replicas=0 -n apelline-dev

# Scale back up
oc scale deployment/openclaw --replicas=1 -n apelline-dev

# Get the public URL
oc get route openclaw -n apelline-dev -o jsonpath='https://{.spec.host}{"\n"}'

# Update a secret value (e.g. rotate OpenAI key)
oc patch secret openclaw-secrets -n apelline-dev \
  --type=merge \
  -p '{"stringData":{"openai-api-key":"sk-NEW-KEY-HERE"}}'
oc rollout restart deployment/openclaw -n apelline-dev
```

---

## File structure

```
.
├── Dockerfile                        # UBI 10 + Node 24 image
├── .github/
│   └── workflows/
│       └── deploy.yml                # CI/CD pipeline (build → push → deploy)
├── manifests/
│   ├── kustomization.yaml            # Kustomize entry point
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── pvc.yaml                      # 10 Gi persistent storage
│   ├── configmap.yaml                # openclaw.json config + AGENTS.md prompt
│   ├── deployment.yaml               # OpenShift-compatible pod spec
│   ├── service.yaml                  # ClusterIP
│   ├── route.yaml                    # TLS-terminated Route (external access)
│   └── secret.yaml.template          # Fill in locally — never commit secret.yaml
└── README.md
```

---

## Customising the agent

Edit `manifests/configmap.yaml`:

- **`openclaw.json`** — change the default model (e.g. `openai/gpt-4o-mini`), add channels, set allowed senders
- **`AGENTS.md`** — the agent's system prompt / persona

Full config reference: <https://docs.openclaw.ai/configuration>

---

## Connecting a chat channel

After deployment, connect the bot to Telegram, Slack, Discord, WhatsApp, etc. from the web dashboard or via config. See the [OpenClaw channel docs](https://docs.openclaw.ai/channels).
