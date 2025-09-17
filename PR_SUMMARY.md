# Fix Kubernetes Deployment Issues for Non-Root Operation

## Summary

This PR addresses critical deployment issues in the Kubernetes manifests that prevented TubeArchivist from running successfully in a non-root, security-hardened environment. This builds on the previous Dockerfile changes that implemented non-root operation, fixing the remaining Kubernetes-specific configuration issues.

## Issues Fixed

### 🔧 Elasticsearch Snapshot Configuration
- **Problem**: Missing `path.repo` environment variable caused snapshot repository setup failures
- **Solution**: Added `path.repo: "/usr/share/elasticsearch/data/snapshot"` to Elasticsearch deployment
- **Impact**: Enables backup/snapshot functionality and allows application startup to complete

### 🔧 Redis Persistence for Non-Root Operation  
- **Problem**: Redis couldn't write RDB snapshots due to permission denied errors when running as non-root
- **Solution**: Disabled RDB persistence (`--save ""`) and append-only logging (`--appendonly no`)
- **Impact**: Resolves Redis connection failures and allows cache operations to work properly

### 🔧 Storage Volume Configuration
- **Problem**: PVC resize conflicts during redeployment 
- **Solution**: Standardized storage sizes (cache: 10Gi, media: 50Gi, ES: 50Gi)
- **Impact**: Clean deployments without storage conflicts

## Files Changed

- `k8s/elasticsearch.yaml` - Added path.repo environment variable
- `k8s/redis.yaml` - Disabled persistence, added proper volume mounting
- `k8s/storage.yaml` - Corrected PVC sizing
- `k8s/DEPLOYMENT_FIXES.md` - Comprehensive documentation of fixes

**Note**: This PR focuses on Kubernetes configuration fixes. The Dockerfile non-root changes were implemented in commit `1d99083a`.

## Security Enhancements

All deployments maintain security best practices:
- ✅ Non-root user execution (UID 10001)
- ✅ Read-only root filesystem where possible
- ✅ Dropped all capabilities
- ✅ seccomp profile enforcement
- ✅ No privilege escalation

## Testing

Deployment tested on Talos OS with Longhorn storage:

```bash
# Apply all manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/storage.yaml  
kubectl apply -f k8s/config.yaml
kubectl apply -f k8s/elasticsearch.yaml
kubectl apply -f k8s/redis.yaml
kubectl apply -f k8s/app.yaml

# Verify deployment
kubectl get pods -n tubearchivist
kubectl logs -n tubearchivist <tubearchivist-pod>
```

## Verification

Successful deployment shows:
- ✅ All pods in Running state
- ✅ TubeArchivist health endpoint responding
- ✅ Elasticsearch indices created
- ✅ Redis cache operational  
- ✅ Celery workers started
- ✅ Snapshot repository configured

## Breaking Changes

None. These are configuration fixes that maintain compatibility with existing Docker deployments.

## Related

- Addresses deployment issues in Kubernetes environments with security policies
- Enables deployment on Talos OS and other hardened distributions
- Maintains compatibility with existing Docker Compose deployments