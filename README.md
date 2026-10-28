# todo-app · End-to-end DevOps lab (CSE3130)

A small but production-shaped Todo app that goes **from laptop to a GitOps-managed,
monitored Kubernetes cluster** using only open-source tools and free tiers.

```
laptop ──► GitHub PR ──► GitHub Actions ──► GHCR image ──► todo-gitops repo ──► Argo CD ──► kind cluster
 Docker     review +      lint/test/build     tagged by       image tag in Git     pulls &      app + Postgres
 Compose    ruleset       Trivy scan          commit SHA      (revert = rollback)  self-heals   Prometheus + Grafana
                                                                                   ▲
                                                     OpenTofu creates the cluster ─┘
```

| Piece | Tool | Cost |
| --- | --- | --- |
| App | Node.js 22, Express 5, PostgreSQL 16 | free / open source |
| Containers | Docker Engine + Compose | open source |
| CI | GitHub Actions (Jenkins for self-study) | free / open source |
| Registry | GitHub Container Registry | free for public images |
| Scanning | Trivy | open source |
| Infrastructure as Code | OpenTofu | open source |
| Kubernetes | kind | open source |
| GitOps CD | Argo CD | open source |
| Monitoring | Prometheus + Grafana | open source |

Two repos work together:

- **todo-app** (this repo): code, Dockerfile, Compose, CI, platform code
- **todo-gitops**: Kubernetes manifests that Argo CD deploys

---

## 0. Prerequisites

Laptop with 8 GB RAM (16 GB comfortable), 20 GB free disk, Linux / macOS / Windows + WSL2, and:
Docker, Git, Node.js 22 and make (installers from each tool's website; on macOS, `git` and `make` come with
`xcode-select --install`). Then `scripts/install-tools.sh` installs **kubectl, Helm, kind, OpenTofu
and the GitHub CLI** from their official downloads, on Linux, WSL2 and macOS (Intel or Apple Silicon); no Homebrew needed.

```bash
bash scripts/install-tools.sh   # kubectl, Helm, kind, OpenTofu, gh (Linux, WSL2, macOS)
gh auth login --scopes workflow # sign in to GitHub (browser); needed for git push
gh auth setup-git
make check                      # every line should say "ok"
make prepull                    # downloads big images once (do this on home Wi-Fi)
```

**Weak laptop or no admin rights?** Open the repo in **GitHub Codespaces**
(Code → Codespaces → Create). Everything is preinstalled via `.devcontainer/`.
Stop the codespace when you finish to save your free quota.

---

## 1. Create your two repos (once)

On GitHub, create two **empty, public** repositories: `todo-app` and `todo-gitops`.

```bash
# config repo first: put your GitHub username into it
cd todo-app
make personalize GITHUB_USER=<your-github-username>

cd ../todo-gitops
git init -b main && git add . && git commit -m "feat: initial gitops config"
git remote add origin https://github.com/<your-github-username>/todo-gitops.git
git push -u origin main
```

```bash
cd ../todo-app
git init -b main && git add . && git commit -m "feat: initial lab template"
git remote add origin https://github.com/<your-github-username>/todo-app.git
git push -u origin main
```

The repo has **no pipeline yet** (there is no `.github/workflows/` folder).
You build it yourself, step by step, in Stage 4.

---

## 2. Stage 1 · Containerize

```bash
make test                                         # lint + 9 unit tests, same as CI
docker build -t todo-api:dev ./app
docker run --rm todo-api:dev id                   # uid=1000 -> not root
docker run -d -p 3000:3000 --name api todo-api:dev   # no DB_HOST -> in-memory store
curl localhost:3000/healthz && docker ps          # STATUS shows (healthy) after ~15 s
docker rm -f api
```

Change one line in `app/src/`, rebuild, and notice the `npm ci` layer is `CACHED`.

## 3. Stage 2 · Local stack with Compose

```bash
make up            # API + PostgreSQL -> http://localhost:3000 (web UI included)
make down && make up          # todos survive: named volume
make clean                    # down -v: volume deleted, todos gone
```

## 4. Stage 3 · Protect `main`

GitHub → todo-app → Settings → Rules → Rulesets → New branch ruleset, target `main`:
require a pull request (1 approval), require status check **test**, block force pushes,
require linear history. From now on every change is a branch + PR.
Do this **after** Stage 4, so the `test` check exists to select.

## 5. Stage 4 · Build the CI pipeline (GitHub Actions)

You grow the pipeline in four increments. After each one: `git diff`, commit, push,
then watch it in the repo's **Actions** tab. The four reference files are in `pipeline/`.

| Step | Adds | Install with | You should see |
| --- | --- | --- | --- |
| 1 | `test` job: lint + unit tests on every push and PR | type it yourself (or `make ci-stage S=1`) | green `test` job |
| 2 | `build` job: build image, Trivy scan (needs `test`) | `make ci-stage S=2` | `test` → `build` |
| 3 | Log in to GHCR, push multi-arch image (push to `main` only) | `make ci-stage S=3` | `todo-api` under your Packages |
| 4 | `promote` job: write the new tag into todo-gitops | `make ci-stage S=4` | `deploy: todo-api <sha>` commit in todo-gitops |

```bash
make ci-stage S=1          # copies pipeline/1-test.yaml to .github/workflows/ci.yaml
git diff
git add .github && git commit -m "ci: pipeline stage 1" && git push
```

**After step 3:** your GitHub profile → **Packages → todo-api → Package settings →
Change visibility → Public**, so the cluster can pull without credentials.

**Before step 4:** create a **fine-grained personal access token** (GitHub → Settings →
Developer settings): repository access = only `todo-gitops`, permission
**Contents: Read and write**, expiry 30 days. In the **todo-app** repo: Settings →
Secrets and variables → Actions → New secret `GITOPS_TOKEN` = that token.

Pull requests run test + build + scan only; nothing is pushed from a PR.

**Self-study:** rebuild the same pipeline in Jenkins: see [`jenkins/README.md`](jenkins/README.md).

## 6. Stage 5 · Platform as code

```bash
make platform      # tofu init + apply: kind cluster, Argo CD, Prometheus, Grafana (~5-10 min)
kubectl get nodes  # control-plane + worker, Ready
kubectl get pods -A
```

Chart versions are pinned in `platform/lab.auto.tfvars`.

## 7. Stage 6 · Kubernetes

```bash
(cd ../todo-gitops && git pull)                # fetch CI's deploy: commit (real image tag)
make secret                                   # DB Secret, created in the cluster only
kubectl apply -k ../todo-gitops/apps/todo     # the ONE manual apply, to learn the objects
make status
curl localhost:8080/version
```

Try: `kubectl -n todo delete pod -l app=todo-api` (ReplicaSet replaces them),
delete the postgres pod (data survives on the PVC).

## 8. Stage 7 · GitOps with Argo CD

```bash
make gitops                # Argo CD now owns the app
make argocd-password
make argocd-ui             # http://localhost:8081  user: admin
```

**Ship a change:** on a branch, edit the title in `app/public/index.html`, open a PR,
merge it. Watch CI → `deploy:` commit in todo-gitops → Argo CD sync (≤ 60 s) →
rolling update. `curl localhost:8080/version` shows the new SHA.

**Bad deploy + rollback:** make `/healthz` in `app/src/app.js` return status 500, merge it.
New pods never become ready and old pods keep serving (`maxUnavailable: 0`).
Roll back in **todo-gitops**: `git revert <deploy commit> && git push`. Then fix the code with a new PR.

**Self-healing:** `kubectl -n todo scale deploy/todo-api --replicas=5` and watch Argo CD put it back to 2.

## 9. Stage 8 · Observability

```bash
make load          # terminal 1: generate traffic
make grafana-ui    # terminal 2: http://localhost:3001  admin / devops-lab
```

Dashboards → **Todo API · RED metrics** (loaded from `todo-gitops/apps/todo/dashboard.yaml`).
`make prometheus-ui` → Status → Targets shows `todo-api` scrape status.

## 10. Cleanup

```bash
make destroy           # deletes the cluster and everything on it
make clean             # Compose volume
docker system prune -f
```

To come back later: `make platform && make secret && make gitops` and Argo CD rebuilds the app from Git.

---

## App reference

| Endpoint | Purpose |
| --- | --- |
| `GET /` | Web UI |
| `GET /api/todos` · `POST /api/todos` `{ "title": "..." }` | List / create |
| `PATCH /api/todos/:id` `{ "done": true }` · `DELETE /api/todos/:id` | Update / delete |
| `GET /healthz` | Liveness: process is alive (never checks the DB) |
| `GET /readyz` | Readiness: DB reachable (503 when not, so traffic stops) |
| `GET /version` | Build version (the commit SHA in CI images) |
| `GET /metrics` | Prometheus metrics (`http_request_duration_seconds`) |

Configuration (env vars): `PORT`, `APP_VERSION`, `LOG_LEVEL`, `DB_HOST`, `DB_PORT`,
`DB_USER`, `DB_PASSWORD`, `DB_NAME`. Without `DB_HOST` the app uses an in-memory store.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `ImagePullBackOff` | GHCR package still private, or CI hasn't run yet | Make package public; check `newTag` in todo-gitops |
| `promote` job fails | `GITOPS_TOKEN` missing, expired or wrong repo | Recreate token scoped to todo-gitops |
| Pods `Pending` | Laptop out of memory | Close apps or use Codespaces |
| `localhost:8080` refuses | Port in use, or cluster not created by `make platform` | Free port 8080 / `make destroy && make platform` |
| Argo CD `OutOfSync` | Manual `kubectl` changes, or repoURL wrong | Change things in Git; check `argocd/todo-app.yaml` |
| No data in Grafana | No traffic, or ServiceMonitor label | `make load`; Prometheus Targets page |
| `tofu apply` times out | Slow image pulls on lab network | Re-run `make platform` (idempotent) |

## Using this for your own project

1. Replace `app/` with your code; keep `/healthz`, `/readyz`, `/metrics` and port 3000
   (or change it in the Dockerfile, `deployment.yaml` and `service.yaml`).
2. Adapt the Dockerfile to your stack using the same rules: pinned base, dependency layer first, non-root numeric UID, healthcheck.
3. Add services to `compose.yaml` first, then to `todo-gitops/apps/todo/`.
4. Keep the workflow, platform code and GitOps flow unchanged.
