# Platform as code: a local Kubernetes cluster (kind) plus the platform
# tools every app on it needs (Argo CD for GitOps, Prometheus + Grafana).
#
#   tofu init && tofu apply
#
# Everything here is open source and runs at zero cost on a laptop or in
# GitHub Codespaces. To target a cloud instead, replace kind_cluster with a
# managed-cluster resource; the Helm releases stay the same.

terraform {
  required_version = ">= 1.8"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.11"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

# ---- the cluster: each node is a Docker container --------------------------
resource "kind_cluster" "lab" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # NodePort 30080 (the todo-api Service) -> http://localhost:8080
      extra_port_mappings {
        container_port = 30080
        host_port      = var.app_host_port
        listen_address = "127.0.0.1"
      }
    }

    node {
      role = "worker"
    }
  }
}

# ---- Helm talks to the cluster above (implicit dependency) -------------------
provider "helm" {
  kubernetes {
    host                   = kind_cluster.lab.endpoint
    client_certificate     = kind_cluster.lab.client_certificate
    client_key             = kind_cluster.lab.client_key
    cluster_ca_certificate = kind_cluster.lab.cluster_ca_certificate
  }
}

# ---- GitOps controller ------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  timeout          = 900

  # Serve the UI over plain HTTP behind `kubectl port-forward` (lab only)
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
  # Check Git every 60s instead of the default 180s, so demos feel snappy
  set {
    name  = "configs.cm.timeout\\.reconciliation"
    value = "60s"
  }
  # Single-node lab: no need for Dex SSO or notifications
  set {
    name  = "dex.enabled"
    value = "false"
  }
  set {
    name  = "notifications.enabled"
    value = "false"
  }
}

# ---- Monitoring: Prometheus Operator + Prometheus + Grafana ------------------
resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.monitoring_chart_version
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900

  # Keep memory low enough for an 8 GB laptop
  set {
    name  = "alertmanager.enabled"
    value = "false"
  }
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "1d"
  }
  # Load Grafana dashboards from ConfigMaps in ANY namespace, so the app's
  # dashboard can live in the GitOps repo next to the app
  set {
    name  = "grafana.sidecar.dashboards.searchNamespace"
    value = "ALL"
  }
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}
