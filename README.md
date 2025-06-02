# Three-Tier Application Kubernetes Deployment

## Overview

This repository contains Helm charts and manifests for deploying a three-tier application consisting of a React frontend (`reactapp`), a Node.js backend (`nodeapp`), and a PostgreSQL database (`postgres`). It includes configurations for high availability, security, monitoring with Prometheus and Grafana, and GitOps deployment using ArgoCD.

## Repository Structure

```
k8s_manifests_repo/
├── helm/
│   ├── postgres/
│   │   ├── templates/
│   │   │   ├── statefulset.yaml
│   │   │   ├── service.yaml
│   │   │   ├── service-headless.yaml
│   │   │   ├── secret.yaml
│   │   │   ├── ingress.yaml
│   │   │   ├── postgres-volume.yaml
│   │   │   ├── storageclass.yaml
│   │   │   ├── serviceaccount.yaml
│   │   │   ├── pdb-postgres.yaml
│   │   │   ├── network-policy.yaml
│   │   │   ├── servicemonitor-postgres.yaml
│   │   │   ├── tests/
│   │   │   │   ├── test-connection.yaml
│   │   │   ├── _helpers.tpl
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── README.md
│   ├── threetier-app-chart/
│   │   ├── templates/
│   │   │   ├── deployments/
│   │   │   │   ├── nodeapp.yaml
│   │   │   │   ├── reactapp.yaml
│   │   │   ├── ingress/
│   │   │   │   ├── reactapp-ingress.yaml
│   │   │   ├── rbac/
│   │   │   │   ├── service-account.yaml
│   │   │   ├── secrets/
│   │   │   │   ├── postgres-secret.yaml
│   │   │   ├── services/
│   │   │   │   ├── nodeapp-service.yaml
│   │   │   │   ├── reactapp-service.yaml
│   │   │   ├── hpa-nodeapp.yaml
│   │   │   ├── hpa-reactapp.yaml
│   │   │   ├── pdb-nodeapp.yaml
│   │   │   ├── pdb-reactapp.yaml
│   │   │   ├── network-policy.yaml
│   │   │   ├── servicemonitor-nodeapp.yaml
│   │   │   ├── servicemonitor-reactapp.yaml
│   │   │   ├── prometheus-rule.yaml
│   │   │   ├── grafana-dashboard.yaml
│   │   │   ├── resource-quota.yaml
│   │   │   ├── _helpers.tpl
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   ├── monitoring/
│   │   ├── templates/
│   │   │   ├── grafana-ingress.yaml
│   │   │   ├── grafana-tls-secret.yaml
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── README.md
├── ingress-controller/
│   ├── nginx/
│   │   ├── 01-installation.md
├── gitops/
│   ├── argocd/
│   │   ├── 01-install.md
│   │   ├── argocd-threetier-app.yaml
│   │   ├── argocd-postgres.yaml
│   │   ├── argocd-monitoring.yaml
│   │   ├── argocd-storageclass.yaml
│   │   ├── argocd-application-controller.yaml
│   │   ├── argocd-redis.yaml
│   │   ├── argocd-redis-pvc.yaml
│   │   ├── argocd-ingress.yaml
│   │   ├── argocd-tls-secret.yaml
├── README.md
├── .gitignore
```

## Prerequisites

- Kubernetes cluster (e.g., EKS on AWS)
- Helm 3.x
- kubectl
- ArgoCD CLI (optional, for manual interaction)
- Access to a Git repository (e.g., GitHub)
- NGINX Ingress Controller installed
- DNS configured for `argocd.local`, `reactapp.local`, and `grafana.local` (or your custom domains)

## Installation

### 1. Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/aws/deploy.yaml
```

### 2. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-storageclass.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-application-controller.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-redis-pvc.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-redis.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-ingress.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-tls-secret.yaml
```

Access the ArgoCD UI at `https://argocd.local`. Log in using the default admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Ensure DNS is configured to point `argocd.local` to the NGINX Ingress Controller’s external IP.

### 3. Deploy Applications via ArgoCD

Apply the ArgoCD Application manifests:

```bash
kubectl apply -f gitops/argocd/argocd-threetier-app.yaml
kubectl apply -f gitops/argocd/argocd-postgres.yaml
kubectl apply -f gitops/argocd/argocd-monitoring.yaml
```

These manifests configure ArgoCD to deploy the `threetier-app-chart`, `postgres`, and monitoring stack from the repository.

### 4. Verify Deployment

- Check ArgoCD UI for application status (`https://argocd.local`).
- Access the React app via the ingress host (`reactapp.local` or configured domain).
- Verify PostgreSQL connectivity using the test pod in the `postgres` chart:

```bash
kubectl exec -it <postgres-test-pod> -- /bin/sh
```

## Monitoring

The monitoring stack includes Prometheus, Grafana, and Alertmanager, deployed via the `kube-prometheus-stack` Helm chart in the `monitoring` namespace. Key components:

- **ServiceMonitors**: Scrape metrics from `nodeapp`, `reactapp`, and `postgres` at `/metrics`.
- **PrometheusRule**: Alerts for high request latency and pod crash looping.
- **Grafana Dashboard**: Visualizes request rates for the three-tier app.
- **Persistence**: Prometheus (10Gi), Grafana (5Gi), and Alertmanager (2Gi) use PVCs for persistent storage.

Access Grafana at `https://grafana.local`:

```bash
kubectl get ingress grafana-ingress -n monitoring
```

Log in with default credentials (admin/prom-operator) and view the `threetier-app` dashboard. Ensure DNS resolves `grafana.local` to the NGINX Ingress Controller’s IP.

For detailed monitoring setup, see `helm/monitoring/README.md`.

## Security Features

- **Pod Security Context**: Non-root users for all pods (`runAsUser: 1000` for nodeapp/reactapp, `999` for postgres).
- **Network Policies**: Restrict traffic to only necessary paths (reactapp -> nodeapp -> postgres).
- **RBAC**: Namespace-scoped Role/RoleBinding for the service account.
- **Secrets**: PostgreSQL credentials stored in Kubernetes Secrets.
- **ArgoCD Persistence**: Persistent storage for `argocd-application-controller` and Redis using PVCs.

## High Availability and Scaling

- **HPA**: Autoscaling for `nodeapp` and `reactapp` based on CPU utilization (70% target).
- **Pod Disruption Budgets**: Ensure at least one pod is available during disruptions.
- **Pod Anti-Affinity**: Spread pods across nodes for fault tolerance.
- **Resource Quota**: Limits resource consumption in the namespace.

## Configuration

Update `values.yaml` in each Helm chart for custom configurations:

- `helm/threetier-app-chart/values.yaml`: Adjust replica counts, image tags, resource limits, and security contexts.
- `helm/postgres/values.yaml`: Configure storage size, database credentials, probes, and authentication settings.
- `helm/monitoring/values.yaml`: Customize Prometheus, Grafana, and Alertmanager settings.
- For ArgoCD, customize `gitops/argocd/argocd-ingress.yaml` with your domain and TLS settings.

## Troubleshooting

- Check pod logs: `kubectl logs <pod-name> -n <namespace>`
- Verify ArgoCD sync status: `argocd app get threetier-app`
- Check Prometheus alerts: Access Prometheus UI via port-forwarding (`kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090`).
- Verify Ingress: `kubectl describe ingress grafana-ingress -n monitoring`

## Contributing

Contributions are welcome! Please submit pull requests to the repository: https://github.com/harikrishnapachava/k8s_manifests_repo