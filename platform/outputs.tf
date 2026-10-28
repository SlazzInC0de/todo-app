output "cluster_name" {
  value = kind_cluster.lab.name
}

output "kubeconfig_path" {
  description = "Use with: export KUBECONFIG=$(tofu output -raw kubeconfig_path)"
  value       = kind_cluster.lab.kubeconfig_path
}

output "app_url" {
  value = "http://localhost:${var.app_host_port}"
}

output "next_steps" {
  value = <<-EOT
    kind export kubeconfig --name ${kind_cluster.lab.name}
    make secret           # create the database Secret (never in Git)
    make gitops           # hand the app to Argo CD
    make argocd-ui        # https://localhost:8081  (user: admin)
    make grafana-ui       # http://localhost:3001   (user: admin)
  EOT
}
