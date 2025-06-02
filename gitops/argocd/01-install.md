# Install ArgoCD

## Prerequisites

- A Kubernetes cluster (e.g., EKS on AWS).
- `kubectl` configured to access the cluster.
- NGINX Ingress Controller installed (see `ingress-controller/nginx/01-installation.md`).
- DNS configured to point `argocd.local` (or your custom domain) to the NGINX Ingress Controller’s external IP.
- A valid TLS certificate for `argocd.local` (or your domain), either self-generated or managed via cert-manager.
- Access to the repository containing the manifests (`gitops/argocd/`).

## Install ArgoCD with Persistent Storage and Ingress

1. Create the `argocd` namespace:

```bash
kubectl create namespace argocd
```

2. Install the core ArgoCD components using the official manifests:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

3. Apply persistence-related manifests to ensure data persists across pod restarts or cluster shutdowns:

```bash
kubectl apply -n argocd -f gitops/argocd/argocd-storageclass.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-application-controller.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-redis-pvc.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-redis.yaml
```

4. Apply Ingress-related manifests to expose the ArgoCD UI via the NGINX Ingress Controller:

```bash
kubectl apply -n argocd -f gitops/argocd/argocd-ingress.yaml
kubectl apply -n argocd -f gitops/argocd/argocd-tls-secret.yaml
```

## Generate TLS Certificate (if needed)

If you don’t have a TLS certificate for `argocd.local`, generate a self-signed certificate:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=argocd.local"
kubectl create secret tls argocd-tls --cert=tls.crt --key=tls.key -n argocd
```

Alternatively, use cert-manager for automated certificate management.

## Access the ArgoCD UI

The ArgoCD UI is exposed via an NGINX Ingress at `https://argocd.local`. Ensure DNS is configured to resolve `argocd.local` to the NGINX Ingress Controller’s external IP.

Get the Ingress details:

```bash
kubectl get ingress argocd-server-ingress -n argocd
```

Log in to the UI using the default admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Verify Installation

- Check pod status: `kubectl get pods -n argocd`
- Verify Ingress: `kubectl describe ingress argocd-server-ingress -n argocd`
- Access the UI at `https://argocd.local` and log in with the admin credentials.

## Troubleshooting

- **Ingress not resolving**: Ensure DNS is configured and the NGINX Ingress Controller is running (`kubectl get pods -n ingress-nginx`).
- **TLS errors**: Verify the `argocd-tls` secret exists and contains valid certificate data (`kubectl describe secret argocd-tls -n argocd`).
- **Pod failures**: Check logs for the `argocd-application-controller` or `argocd-redis` pods (`kubectl logs <pod-name> -n argocd`).
- **Persistence issues**: Ensure the `argocd-storage` StorageClass is supported by your cloud provider and the PVCs are bound (`kubectl get pvc -n argocd`).

## Notes

- The `argocd-server` service is a `ClusterIP` type by default, as the Ingress handles external access.
- Replace `argocd.local` with your custom domain if needed.
- For high availability, consider using `redis-ha` or a managed Redis service instead of the default Redis Deployment.
- The persistence manifests use AWS EBS (`gp3`); adjust the `StorageClass` for your environment (e.g., GCE PD, Azure Disk).