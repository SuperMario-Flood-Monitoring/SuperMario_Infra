# SuperMario Infra

Production deployment repository for the SuperMario Flood Monitoring services.

## Services

- `frontend`: React static image served by nginx
- `backend`: Django + Channels + SWMM runtime
- `llm`: FastAPI + LangChain server
- `postgres`: production database
- `redis`: shared runtime/cache broker candidate
- `nginx`: public reverse proxy and HTTPS endpoint
- `certbot`: Let's Encrypt certificate renewal container

## Production Host

- Domain: `supermario.o-r.kr`
- External IP: `59.9.136.144`
- Internal IP: `192.168.0.101`
- SSH user: `seoktae`
- Deploy path: `/home/seoktae/Documents/TEAM_SUPERMARIO`

## First Server Setup

```bash
cp .env.example .env
vi .env
chmod +x scripts/*.sh
DEPLOY_PATH=/home/seoktae/Documents/TEAM_SUPERMARIO scripts/server-init.sh
scripts/init-letsencrypt.sh
```

Before running Let's Encrypt initialization, ensure:

- `supermario.o-r.kr` points to `59.9.136.144`
- router forwards ports `80`, `443`, and `22` to the Ubuntu server
- GHCR images are public, or the server has already logged in to GHCR

## Production Environment Secret

Use `docs/production-env.example.yml` as a template, fill real production values locally, then base64-encode it and save it as the `PRODUCTION_ENV_YAML_B64` repository secret in `SuperMario_Infra`.

```bash
base64 -i production-env.yml | pbcopy
```

The deploy workflow converts this secret into `/home/seoktae/Documents/TEAM_SUPERMARIO/.env` on every deployment.

## Deployment

Service repositories publish images to GHCR on `prod` branch push. They then send `repository_dispatch` to this repository.

The Infra workflow syncs this repo to the server and runs:

```bash
scripts/deploy.sh backend ghcr.io/supermario-flood-monitoring/supermario-django <commit-sha>
```

Each service has its own active color, so deploying `backend` only switches backend traffic.
