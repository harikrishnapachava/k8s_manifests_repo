# Monitoring Stack for Three-Tier Application

## Overview

This Helm chart deploys a monitoring stack using `kube-prometheus-stack` to monitor the three-tier application (`nodeapp`, `reactapp`, `postgres`). It includes Prometheus for metrics collection, Grafana for visualization, and Alertmanager for alert handling, along with `kube-state-metrics` and `prometheus-node-exporter` for cluster-level metrics.

## Prerequisites

- Kubernetes cluster (e.g., EKS on AWS).
- Helm 3.x and `kubectl` configured.
- ArgoCD installed (see `gitops/argocd/01-install.md`).
- NGINX Ingress Controller installed (see `ingress-controller/nginx/01-installation.md`).
- DNS configured for `grafana.local` (or your custom domain).
- A valid TLS certificate for `grafana.local`, either self-generated or managed via cert-manager.
- The `argocd-storage` StorageClass available (see `gitops/argocd/argocd-storageclass.yaml`).

## Installation

The monitoring stack is deployed via ArgoCD using the `helm/monitoring` chart.

1. Apply the ArgoCD Application manifest:

```bash
kubectl apply -f gitops/argocd/argocd-monitoring.yaml
```

This deploys the `kube-prometheus-stack` chart in the `monitoring` namespace, creating:
- Prometheus for metrics collection.
- Grafana for visualization.
- Alertmanager for alert handling.
- `kube-state-metrics` for Kubernetes object metrics.
- `prometheus-node-exporter` for node-level metrics.

2. Apply the Grafana Ingress and TLS secret:

```bash
kubectl apply -f helm/monitoring/templates/grafana-ingress.yaml
kubectl apply -f helm/monitoring/templates/grafana-tls-secret.yaml
```

If you don’t have a TLS certificate, generate a self-signed one:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=grafana.local"
kubectl create secret tls grafana-tls --cert=tls.crt --key=tls.key -n monitoring
```

## Configuration

The `helm/monitoring/values.yaml` file configures the monitoring stack:
- **Prometheus**: Scrapes metrics from `ServiceMonitors` with `release: threetier-app` label, using a 10Gi PVC for persistence.
- **Grafana**: Loads dashboards from ConfigMaps with `grafana_dashboard` label, uses a 5Gi PVC for persistence.
- **Alertmanager**: Handles alerts with a 2Gi PVC for persistence.
- **ServiceMonitors**:
  - `nodeapp` and `reactapp`: Scrape metrics at `/metrics` endpoints (port 80).
  - `postgres`: Scrapes metrics from a `prometheus-postgres-exporter` sidecar at `/metrics` (port 9187).
- **PrometheusRule**: Defines alerts for high request latency and pod crash looping.

Customize settings by editing `helm/monitoring/values.yaml`.

## Accessing Grafana

Access Grafana at `https://grafana.local`. Ensure DNS resolves `grafana.local` to the NGINX Ingress Controller’s external IP:

```bash
kubectl get svc -n ingress-nginx
```

Log in with default credentials:
- Username: `admin`
- Password: `prom-operator`

The `threetier-app-grafana-dashboard` ConfigMap provides a dashboard visualizing request rates. Additional dashboards for `kube-state-metrics` and `node-exporter` are included by default.

## Accessing Prometheus and Alertmanager

Prometheus and Alertmanager are not exposed externally by default. Use port-forwarding for access:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093
```

Access at `http://localhost:9090` (Prometheus) or `http://localhost:9093` (Alertmanager).

To expose them via Ingress, create additional Ingress manifests similar to `grafana-ingress.yaml`.

## Persistence

- **Prometheus**: Metrics are stored in a 10Gi PVC (`argocd-storage` StorageClass).
- **Grafana**: Dashboards and settings are stored in a 5Gi PVC.
- **Alertmanager**: Alert state is stored in a 2Gi PVC.
- Data persists across pod restarts and cluster shutdowns.

## Troubleshooting

- **Metrics not scraped**:
  - For `postgres`, verify the `postgres-exporter` sidecar is running (`kubectl logs <postgres-pod> -c postgres-exporter -n default`).
  - Ensure `nodeapp` and `reactapp` expose `/metrics` endpoints.
- **Grafana dashboard missing**: Verify the `threetier-app-grafana-dashboard` ConfigMap and `grafana.sidecar.dashboards.enabled: true`.
- **Alerts not firing**: Check `kubectl describe prometheusrule threetier-app-alerts -n default`.
- **Persistence issues**: Verify PVCs are bound (`kubectl get pvc -n monitoring`).
- **Ingress errors**: Check `kubectl describe ingress grafana-ingress -n monitoring` and ensure DNS is configured.

## Notes

- The `kube-prometheus-stack` version is `51.8.0`. Update `Chart.yaml` for newer versions.
- For Alertmanager notifications (e.g., Slack, email), add configuration to `alertmanager.alertmanagerSpec` in `values.yaml`.
- The `postgres-exporter` sidecar uses `prometheuscommunity/postgres-exporter:latest` and connects to PostgreSQL using credentials from the `postgres-credentials` secret.