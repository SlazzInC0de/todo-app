# One command per lab step. Run `make` to see them all.
# Works on Linux, macOS, WSL2 and GitHub Codespaces.

SHELL        := /bin/bash
CLUSTER      ?= devops-lab
GITOPS_DIR   ?= ../todo-gitops
# Your GitHub username, taken from this repo's origin remote (override: make X GITHUB_USER=me)
GITHUB_USER  ?= $(shell git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#')
APP_URL      ?= http://localhost:8080

.DEFAULT_GOAL := help
.PHONY: help check prepull test up down logs ci-stage platform kubeconfig personalize secret gitops status \
        jenkins-up jenkins-password jenkins-down argocd-password argocd-ui grafana-ui prometheus-ui load destroy clean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

check: ## Pre-session smoke test: are all tools installed?
	@for t in docker git node kubectl kind tofu helm gh; do \
	  if command -v $$t >/dev/null; then echo "  ok   $$t"; else echo "  MISSING $$t"; fi; done
	@docker info >/dev/null 2>&1 && echo "  ok   docker daemon running" || echo "  MISSING docker daemon (is Docker started?)"
	@gh auth status 2>&1 | grep -q "'workflow'" && echo "  ok   GitHub login with workflow scope" \
	  || echo "  MISSING GitHub login: gh auth login --scopes workflow && gh auth setup-git"

prepull: ## Pre-session: download big images and providers once (run on home Wi-Fi)
	docker pull node:22-alpine
	docker pull postgres:16-alpine
	@echo "Pulling the kind node image (creates and deletes a throwaway cluster)..."
	kind create cluster --name prepull && kind delete cluster --name prepull
	cd platform && tofu init
	cd app && npm ci
	@echo "Pre-pull complete. You are ready for the session."

# ---- Stage 1-2: build and run locally -----------------------------------------
test: ## Lint and unit-test the app (same as CI)
	cd app && npm ci && npm run lint && npm test

up: ## Start API + PostgreSQL with Docker Compose -> http://localhost:3000
	@[ -f .env ] || (cp .env.example .env && echo "Created .env from .env.example")
	docker compose up -d --build
	@echo "App: http://localhost:3000"

down: ## Stop the Compose stack (data volume is kept)
	docker compose down

logs: ## Follow Compose logs
	docker compose logs -f

# ---- Stage 4: build the CI pipeline step by step ------------------------------
ci-stage: ## Install pipeline stage S (1-4) as .github/workflows/ci.yaml, e.g. make ci-stage S=2
	@[ -n "$(S)" ] || (echo "Usage: make ci-stage S=<1|2|3|4>"; exit 1)
	@f=$$(ls pipeline/$(S)-*.yaml 2>/dev/null) || (echo "No stage $(S) in pipeline/"; exit 1); \
	mkdir -p .github/workflows && cp "$$f" .github/workflows/ci.yaml && \
	echo "Installed $$f -> .github/workflows/ci.yaml"
	@git diff --stat -- .github/workflows/ci.yaml 2>/dev/null || true
	@echo "Next: git diff, then: git add .github && git commit -m 'ci: pipeline stage $(S)' && git push"

# ---- Jenkins (self-study) -------------------------------------------------------
jenkins-up: ## Self-study: start Jenkins on http://localhost:8090
	docker compose -f jenkins/compose.yaml up -d --build

jenkins-password: ## Self-study: print the Jenkins initial admin password
	@docker compose -f jenkins/compose.yaml exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

jenkins-down: ## Self-study: stop Jenkins and delete its data
	docker compose -f jenkins/compose.yaml down -v

# ---- Stage 5: platform as code ---------------------------------------------------
platform: ## Create kind cluster + Argo CD + monitoring with OpenTofu
	cd platform && tofu init && tofu apply
	kind export kubeconfig --name $(CLUSTER)
	kubectl get nodes

kubeconfig: ## Point kubectl at the lab cluster
	kind export kubeconfig --name $(CLUSTER)

# ---- Stage 6-7: GitOps -------------------------------------------------------------
personalize: ## Put your GitHub username into the config repo (run once, then commit there)
	@[ -n "$(GITHUB_USER)" ] || (echo "Set GITHUB_USER=<your-github-username>"; exit 1)
	@user=$$(echo "$(GITHUB_USER)" | tr '[:upper:]' '[:lower:]'); \
	sed -i.bak "s#github.com/your-github-user/#github.com/$(GITHUB_USER)/#" $(GITOPS_DIR)/argocd/todo-app.yaml && \
	sed -i.bak "s#ghcr.io/your-github-user/#ghcr.io/$$user/#" $(GITOPS_DIR)/apps/todo/kustomization.yaml && \
	sed -i.bak "s#GITHUB_USER = 'your-github-user'#GITHUB_USER = '$$user'#" jenkins/Jenkinsfile && \
	rm -f $(GITOPS_DIR)/argocd/todo-app.yaml.bak $(GITOPS_DIR)/apps/todo/kustomization.yaml.bak jenkins/Jenkinsfile.bak
	@echo "Updated $(GITOPS_DIR). Now commit and push it:"
	@echo "  cd $(GITOPS_DIR) && git commit -am 'chore: set GitHub user' && git push"

secret: ## Create the database Secret in the cluster (once; never stored in Git)
	kubectl create namespace todo --dry-run=client -o yaml | kubectl apply -f -
	@if kubectl -n todo get secret todo-db >/dev/null 2>&1; then \
	  echo "Secret todo-db already exists (not rotating: the database volume uses it)"; \
	else \
	  kubectl -n todo create secret generic todo-db \
	    --from-literal=DB_USER=todo \
	    --from-literal=DB_PASSWORD="$$(openssl rand -hex 16)"; \
	fi

gitops: ## Hand the app to Argo CD (the last manual apply of the day)
	kubectl apply -f $(GITOPS_DIR)/argocd/todo-app.yaml
	@echo "Watch it sync: make argocd-ui"

status: ## Show the app's Kubernetes objects
	kubectl -n todo get deploy,rs,pods,svc,pvc
	@echo; curl -s $(APP_URL)/version && echo

argocd-password: ## Print the Argo CD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

argocd-ui: ## Open Argo CD on http://localhost:8081 (user admin, password: make argocd-password)
	kubectl -n argocd port-forward svc/argocd-server 8081:80

grafana-ui: ## Open Grafana on http://localhost:3001 (user admin / devops-lab)
	kubectl -n monitoring port-forward svc/monitoring-grafana 3001:80

prometheus-ui: ## Open Prometheus on http://localhost:9090 (Status -> Targets)
	kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090

load: ## Generate traffic for the dashboards (Ctrl+C to stop)
	@echo "Sending traffic to $(APP_URL) ..."
	@while true; do \
	  curl -s -o /dev/null $(APP_URL)/api/todos; \
	  curl -s -o /dev/null -X POST -H 'content-type: application/json' -d '{"title":"load test"}' $(APP_URL)/api/todos; \
	  curl -s -o /dev/null $(APP_URL)/api/todos/does-not-exist; \
	  sleep 0.1; done

# ---- cleanup ---------------------------------------------------------------------
destroy: ## Delete the whole cluster and everything on it
	cd platform && tofu destroy

clean: ## Stop Compose and delete its data volume
	docker compose down -v
