# Deploy TubeArchivist on Talos (Kubernetes)

These manifests are tailored for Talos OS + Kubernetes, focusing on non-root containers and ES compatibility.

## Prerequisites
- A default `StorageClass` in your cluster, or edit the PVCs to specify your class.
- Ingress controller (e.g., `ingress-nginx`) if you apply `ingress.yaml`.
- Container registry with your built image of `tubearchivist:rootless`.
- Optional: Node sysctl tuned for Elasticsearch (Talos kernel):
  - vm.max_map_count >= 262144
  - fs.file-max sufficiently high
  - On Talos, set via machine config `sysctls`.

## Resources
- Namespace: `k8s/namespace.yaml`
- Config & Secrets: `k8s/config.yaml`
- Storage (PVCs): `k8s/storage.yaml` (cache/media/ES data)
- Redis: `k8s/redis.yaml`
- Elasticsearch: `k8s/elasticsearch.yaml` (single-node, security on, HTTP/transport TLS off)
- App: `k8s/app.yaml`
- Ingress (optional): `k8s/ingress.yaml`

## Important settings
- `TA_HOST` in `k8s/config.yaml` should match how you access the app (e.g. `https://ta.example.com`). You can list multiple space-separated origins.
- App runs as non-root: `runAsUser: 10001`, `fsGroup: 10001`.
- ES runs as UID/GID 1000 with an Unconfined seccomp profile to mirror the Compose workaround. If your Talos kernel/security policy allows, prefer a tighter profile.

## Apply order
```sh
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/config.yaml
kubectl apply -f k8s/storage.yaml
kubectl apply -f k8s/redis.yaml
kubectl apply -f k8s/elasticsearch.yaml
kubectl apply -f k8s/app.yaml
# Optional ingress
kubectl apply -f k8s/ingress.yaml
```

## Image
Edit `k8s/app.yaml` and set:
```
image: <your-registry>/tubearchivist:rootless
```
Push your image to that registry before applying the manifests.

## Verify
```sh
kubectl -n tubearchivist get pods,svc
kubectl -n tubearchivist logs deploy/tubearchivist -f
kubectl -n tubearchivist logs deploy/archivist-es -f
```

If ES fails to start due to seccomp or mmap limits, adjust Talos machine config sysctls and re-check. TLS is disabled for ES HTTP/transport for simplicity; you can enable it and update `ES_URL`/certs accordingly.
