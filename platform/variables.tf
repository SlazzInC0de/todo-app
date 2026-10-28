variable "cluster_name" {
  description = "Name of the kind cluster (also used by `kind export kubeconfig --name`)"
  type        = string
  default     = "devops-lab"
}

variable "app_host_port" {
  description = "Port on your laptop that forwards to the app's NodePort 30080"
  type        = number
  default     = 8080
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (pinned in lab.auto.tfvars)"
  type        = string
}

variable "monitoring_chart_version" {
  description = "kube-prometheus-stack Helm chart version (pinned in lab.auto.tfvars)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password (lab only; never commit real passwords)"
  type        = string
  default     = "devops-lab"
  sensitive   = true
}
