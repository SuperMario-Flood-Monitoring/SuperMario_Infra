# Deployment Flow

## Event Flow

```text
Service repo prod push
  -> GitHub Actions build Docker image
  -> Push image to GHCR
  -> Send repository_dispatch to SuperMario_Infra
  -> SuperMario_Infra workflow SSHs to server
  -> New image is pulled on the inactive color
  -> Health check passes
  -> nginx upstream switches to the new color
```

## Blue/Green State

Active colors are stored per service in `runtime/active-colors.env`.

```text
FRONTEND_ACTIVE=blue
BACKEND_ACTIVE=blue
LLM_ACTIVE=blue
```

This means frontend, backend, and LLM can be deployed independently.

## HTTPS

The first certificate is issued by:

```bash
scripts/init-letsencrypt.sh
```

After that, the `certbot` container renews certificates every 12 hours. nginx serves ACME challenges from a shared Docker volume.

## Required GitHub Secrets

In `SuperMario_Infra`:

```text
SERVER_HOST
SERVER_USER
SERVER_PORT
SSH_PRIVATE_KEY
DEPLOY_PATH
PRODUCTION_ENV_YAML_B64
```

In each public service repository:

```text
INFRA_DISPATCH_TOKEN
```

`INFRA_DISPATCH_TOKEN` must be able to create `repository_dispatch` events on `SuperMario_Infra`.

## Production Env YAML

Use `docs/production-env.example.yml` as the shape for production config, fill real values locally, then store it as a base64 GitHub Secret:

```bash
base64 -i production-env.yml | pbcopy
```

Add the copied value to `SuperMario_Infra` repository secret:

```text
PRODUCTION_ENV_YAML_B64
```

During deployment, the workflow decodes this secret, converts it to `.env`, and uploads it to the server deploy path.
