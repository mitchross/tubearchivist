# TubeArchivist Kubernetes Deployment Fixes & Improvements

## Overview

This document details the comprehensive fixes and improvements made to enable successful deployment of TubeArchivist on Kubernetes with Talos OS, including non-root container security enhancements and proper volume handling.

## Problem Summary

The initial Kubernetes deployment faced several critical issues:

1. **Elasticsearch Snapshot Repository**: Missing `path.repo` configuration preventing snapshot functionality
2. **Redis Persistence Issues**: Permission denied errors when running as non-root user
3. **Storage Configuration**: PVC size conflicts during redeployment
4. **Non-root Security**: Containers needed proper configuration for rootless operation

## Fixes Applied

### 1. Elasticsearch Configuration (`k8s/elasticsearch.yaml`)

**Issue**: Elasticsearch was missing the `path.repo` environment variable required for snapshot repositories.

**Error**:
```
🗙 path.repo env var not found. set the following env var to the ES container:
path.repo=/usr/share/elasticsearch/data/snapshot
```

**Fix Applied**:
```yaml
env:
- name: path.repo
  value: "/usr/share/elasticsearch/data/snapshot"
```

**Impact**: 
- Enables TubeArchivist snapshot/backup functionality
- Allows application startup to complete successfully
- Resolves startup failure in `ta_startup` management command

### 2. Redis Persistence Configuration (`k8s/redis.yaml`)

**Issue**: Redis running as non-root user couldn't write RDB snapshots to `/data` directory.

**Error**:
```
Failed opening the temp RDB file temp-3812.rdb (in server root dir /data) for saving: Permission denied
MISCONF Redis is configured to save RDB snapshots, but it's currently unable to persist to disk
```

**Fix Applied**:
```yaml
containers:
- name: redis
  image: redis:7
  command:
  - redis-server
  - --save
  - ""
  - --appendonly
  - "no"
  volumeMounts:
  - name: redis-data
    mountPath: /data
volumes:
- name: redis-data
  emptyDir: {}
```

**Impact**:
- Disables RDB persistence to avoid permission issues
- Uses in-memory storage suitable for cache workload
- Enables proper Redis operation with non-root security context
- Allows TubeArchivist to connect to Redis successfully

### 3. Storage Volume Fixes (`k8s/storage.yaml`)

**Issue**: PVC resize conflicts during redeployment when trying to shrink volumes.

**Error**:
```
The PersistentVolumeClaim "media-pvc" is invalid: spec.resources.requests.storage: Forbidden: field can not be less than status.capacity
```

**Fix Applied**:
- Complete namespace deletion and recreation for clean slate
- Corrected storage sizes:
  - `cache-pvc`: 10Gi
  - `media-pvc`: 50Gi (corrected from conflicting 200Gi)
  - `es-data-pvc`: 50Gi

**Impact**:
- Clean storage deployment without conflicts
- Appropriate sizing for different data types
- Successful PVC binding

## Docker & Application Changes (Previously Implemented)

### Non-root Security Implementation

The Dockerfile was updated in commit `1d99083a` to support non-root operation. Key changes made:

#### Dockerfile Security Changes:

**Virtual Environment for Dependencies**:
```dockerfile
# OLD: Install to root user
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# NEW: Use virtual environment 
COPY --from=builder /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:/home/ta/.local/bin:/app/.local/bin:$PATH
```

**Non-root User Creation**:
```dockerfile
# Create non-root user and group
RUN groupadd -g 10001 ta && useradd -u 10001 -g ta -m -s /usr/sbin/nologin ta

# Fix permissions for non-root operation
RUN mkdir -p /cache /youtube /app /app/.local/bin \
    /var/cache/nginx /var/log/nginx /var/run/nginx \
    /var/lib/nginx/body \
    && chown -R ta:ta /cache /youtube /app /var/cache/nginx /var/log/nginx /var/run/nginx /var/lib/nginx

# Configure nginx for non-root
RUN sed -i 's/^user www\-data\;$/user ta\;/' /etc/nginx/nginx.conf \
    && sed -i 's|pid /run/nginx.pid;|pid /var/run/nginx/nginx.pid;|' /etc/nginx/nginx.conf

# Switch to non-root user
USER ta:ta
```

**Build Process Improvements**:
```dockerfile
# Better cleanup and caching
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc libldap2-dev libsasl2-dev libssl-dev git \
    && rm -rf /var/lib/apt/lists/*

# Virtual environment in builder stage
RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
RUN pip install --no-cache-dir -r /requirements.txt
```

#### Application Runtime Features:
- Virtual environment path configuration for non-root user
- User-local pip installation path
- Proper file permissions for all required directories
- Nginx configured to run on unprivileged port 8000

## Kubernetes Security Context

All deployments use proper security contexts:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
```

Container-level security:
```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ "ALL" ]
```

## Deployment Process

### Successful Startup Sequence

After fixes, the application startup completes successfully:

1. **Environment Setup** ✅
   - All expected environment variables verified
   - ES user configuration confirmed

2. **Connection Check** ✅
   - Redis connection established
   - Elasticsearch connection verified
   - ES version compatibility confirmed
   - Path.repo configuration validated

3. **Application Start** ✅
   - Cache folders created
   - Redis keys cleared
   - Download cache cleaned
   - ES index mappings validated
   - Snapshot repository configured
   - Schedules initialized

4. **Background Services** ✅
   - Celery worker started with 4 concurrency
   - Celery beat scheduler started
   - Nginx web server started

## Verification Commands

To verify successful deployment:

```bash
# Check all pods are running
kubectl get pods -n tubearchivist

# Verify TubeArchivist health endpoint
kubectl exec -n tubearchivist <pod-name> -- curl -s http://localhost:8000/api/health/

# Check logs for successful startup
kubectl logs -n tubearchivist <pod-name>

# Verify Redis connectivity
kubectl logs -n tubearchivist <redis-pod> --tail=20

# Check Elasticsearch status
kubectl logs -n tubearchivist <es-pod> --tail=20
```

## Configuration Files Modified

1. **`k8s/elasticsearch.yaml`**: Added `path.repo` environment variable
2. **`k8s/redis.yaml`**: Disabled persistence, added volume mount
3. **`k8s/storage.yaml`**: Corrected PVC sizes

## Best Practices Implemented

1. **Security**: All containers run as non-root with minimal privileges
2. **Resource Management**: Appropriate CPU/memory limits and requests
3. **Storage**: Proper volume handling for different data types
4. **Networking**: Internal service communication using ClusterIP
5. **Configuration**: Externalized configuration via ConfigMaps and Secrets
6. **Health Checks**: Proper liveness and readiness probes

## Future Considerations

1. **Redis Persistence**: Consider using a Redis StatefulSet with persistent storage if cache persistence is required
2. **Backup Strategy**: Implement proper backup procedures for Elasticsearch data
3. **Monitoring**: Add monitoring and alerting for production deployments
4. **Scaling**: Consider horizontal scaling options for high-availability deployments

## Summary

The deployment fixes addressed fundamental issues with:
- Elasticsearch snapshot configuration
- Redis non-root operation
- Storage volume management
- Container security contexts

These changes enable TubeArchivist to run successfully on Kubernetes with proper security practices and reliable operation.