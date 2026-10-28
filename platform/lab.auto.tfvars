# Pinned chart versions: the whole class installs exactly the same platform.
# Instructor: bump these once, before the session, after a dry run.
#   helm search repo argo/argo-cd
#   helm search repo prometheus-community/kube-prometheus-stack
argocd_chart_version     = "10.10.0"
monitoring_chart_version = "92.1.0"
