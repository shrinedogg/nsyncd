# Syncoid Docker Container

Automated ZFS replication from a remote pool to a local NFS-mounted destination using syncoid.

## Features

- Runs syncoid every 15 minutes via cron
- SSH key mounted securely as read-only
- Configurable via environment variables
- Automatic retry on failure
- Optional sync on container start
- Read-only filesystem compatible

## Quick Start

### Docker Compose

```bash
docker-compose up -d
```

### Manual Docker Run

```bash
docker build -t nsyncd .

docker run -d \
  --name nsyncd \
  --privileged \
  -e REMOTE_USER=<SSH_USERNAME> \
  -e REMOTE_HOST=<REMOTE_HOST_IP> \
  -e REMOTE_PORT=<SSH_PORT> \
  -e REMOTE_DATASET=<REMOTE_ZFS_DATASET> \
  -e LOCAL_DATASET=/nfs-share \
  -e RUN_ON_START=true \
  -v /path/to/ssh/key:/root/.ssh/id_rsa:ro \
  -v /path/to/nfs/mount:/nfs-share \
  nsyncd
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REMOTE_USER` | - | SSH username for remote host |
| `REMOTE_HOST` | - | Remote ZFS server IP/hostname |
| `REMOTE_PORT` | - | SSH port |
| `REMOTE_DATASET` | - | Remote ZFS dataset to sync |
| `LOCAL_DATASET` | `/nfs-share` | Local destination path |
| `SSH_KEY` | `/root/.ssh/id_rsa` | Path to SSH key inside container |
| `SSH_CIPHER` | `chacha20-poly1305@openssh.com` | SSH cipher to use |
| `MBUFFER_SIZE` | `1G` | mbuffer size for transfers |
| `MAX_RETRIES` | `3` | Number of retry attempts |
| `RUN_ON_START` | `false` | Run sync immediately on start |

### Volume Mounts

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| `/path/to/ssh/key` | `/root/.ssh/id_rsa:ro` | SSH private key (read-only) |
| `/path/to/nfs/mount` | `/nfs-share` | NFS mount point |

## Kubernetes Deployment

Kubernetes manifests are provided in the `k8s/` directory.

### Prerequisites

- NFS CSI driver or static PV/PVC for NFS mount
- External Secrets Operator (for secret management)
- ClusterSecretStore configured

### Deploy

1. **Update configuration** in `k8s/configmap.yaml`:
   ```yaml
   REMOTE_USER: "<SSH_USERNAME>"
   REMOTE_PORT: "<SSH_PORT>"
   REMOTE_DATASET: "<REMOTE_ZFS_DATASET>"
   ```

2. **Update external secret** in `k8s/external-secret.yaml` with your secret store paths

3. **Update NFS PV** in `k8s/pv-pvc.yaml`:
   ```yaml
   nfs:
     server: <NFS_SERVER_IP>
     path: <NFS_EXPORT_PATH>
   ```

4. **Build and push image**:
   ```bash
   docker build -t <REGISTRY>/nsyncd:latest .
   docker push <REGISTRY>/nsyncd:latest
   ```

5. **Deploy**:
   ```bash
   kubectl apply -k k8s/
   ```

## Logs

View sync logs:

```bash
# Docker
docker logs -f nsyncd

# Kubernetes
kubectl logs -f deployment/nsyncd -n <NAMESPACE>
```

## Customizing the Schedule

To change the sync interval, modify the cron expression in the Dockerfile:

```dockerfile
# Current: every 15 minutes
RUN echo "*/15 * * * * /usr/local/bin/sync.sh > /proc/1/fd/1 2>/proc/1/fd/2" > /etc/cron.d/syncoid-cron

# Example: every hour
RUN echo "0 * * * * /usr/local/bin/sync.sh > /proc/1/fd/1 2>/proc/1/fd/2" > /etc/cron.d/syncoid-cron

# Example: every 30 minutes
RUN echo "*/30 * * * * /usr/local/bin/sync.sh > /proc/1/fd/1 2>/proc/1/fd/2" > /etc/cron.d/syncoid-cron
```

## Troubleshooting

### SSH Connection Issues

1. Ensure the SSH key has correct permissions:
   ```bash
   chmod 600 /path/to/ssh/key
   ```

2. Test SSH connection manually:
   ```bash
   # Docker
   docker exec -it nsyncd ssh -i /root/.ssh/id_rsa -p <SSH_PORT> <SSH_USERNAME>@<REMOTE_HOST_IP>
   
   # Kubernetes
   kubectl exec -it deployment/nsyncd -n <NAMESPACE> -- ssh -i /root/.ssh/id_rsa -p <SSH_PORT> <SSH_USERNAME>@<REMOTE_HOST_IP>
   ```

### NFS Mount Issues

1. Ensure NFS utilities are available and the share is accessible
2. For Docker: Check if the host has the NFS share mounted before starting the container
3. For Kubernetes: Verify the PV/PVC is bound and the NFS server is reachable

### Manual Sync

Trigger a sync manually:

```bash
# Docker
docker exec nsyncd /usr/local/bin/sync.sh

# Kubernetes
kubectl exec deployment/nsyncd -n <NAMESPACE> -- /usr/local/bin/sync.sh
```

## File Structure

```
├── Dockerfile              # Container image definition
├── docker-compose.yml      # Docker Compose configuration
├── sync.sh                 # Syncoid sync script
├── entrypoint.sh           # Container entrypoint
├── README.md               # This file
└── k8s/
    ├── kustomization.yaml  # Kustomize configuration
    ├── namespace.yaml      # Namespace definition
    ├── configmap.yaml      # Environment configuration
    ├── external-secret.yaml# ExternalSecret for SSH key & secrets
    ├── pv-pvc.yaml         # NFS PersistentVolume/Claim
    └── deployment.yaml     # Deployment specification
```
