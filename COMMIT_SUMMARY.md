# Commit Summary

## Main Commit Message
```
fix(k8s): resolve deployment issues for non-root operation

- Add path.repo env var to Elasticsearch for snapshot functionality
- Disable Redis persistence to fix permission errors with non-root user  
- Correct PVC storage sizes to prevent resize conflicts
- Add comprehensive deployment documentation

Fixes deployment failures on security-hardened Kubernetes distributions
like Talos OS while maintaining Docker compatibility.
```

## Individual File Changes

### k8s/elasticsearch.yaml
```
fix(k8s): add path.repo environment variable to Elasticsearch

Enables snapshot repository functionality required for TubeArchivist
backup features. Resolves startup failures in ta_startup command.
```

### k8s/redis.yaml  
```
fix(k8s): disable Redis persistence for non-root operation

Resolves permission denied errors when Redis attempts to write RDB
snapshots as non-root user. Uses in-memory storage suitable for 
cache workload.
```

### k8s/storage.yaml
```
fix(k8s): standardize PVC storage sizes

Corrects media-pvc size to 50Gi to prevent resize conflicts during
redeployment. Ensures consistent storage allocation across components.
```

## Related Issues Resolved

- Elasticsearch snapshot repository setup failures
- Redis MISCONF errors preventing cache operations  
- PVC resize conflicts during namespace recreation
- Application startup hanging at connection check phase
- Celery worker connection failures to Redis