# nsyncd - ZFS Syncoid Container

Automated ZFS-to-ZFS replication from a remote pool to a local pool using syncoid. Designed to run as a Kubernetes CronJob.

## Features

- ZFS-to-ZFS replication via SSH
- Runs as a one-shot container (suitable for Kubernetes CronJob)
- SSH key mounted securely as read-only
- Configurable via environment variables
- Automatic retry on failure (default: 3 attempts)
- Read-only filesystem compatible
- Consistent snapshot naming with `--identifier`

## Quick Start

### Docker

```bash
docker build -t nsyncd .

docker run --rm \
  --privileged \
  -e REMOTE_USER=<SSH_USERNAME> \
  -e REMOTE_HOST=<REMOTE_HOST_IP> \
  -e REMOTE_PORT=<SSH_PORT> \
  -e REMOTE_DATASET=<REMOTE_ZFS_DATASET> \
  -e LOCAL_DATASET=<LOCAL_ZFS_DATASET> \
  -v /path/to/ssh/key:/root/.ssh/id_rsa:ro \
  -v /dev/zfs:/dev/zfs \
  nsyncd
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REMOTE_USER` | - | SSH username for remote host |
| `REMOTE_HOST` | - | Remote ZFS server IP/hostname |
| `REMOTE_PORT` | - | SSH port |
| `REMOTE_DATASET` | - | Remote ZFS dataset to sync (e.g., `tank/media`) |
| `LOCAL_DATASET` | - | Local ZFS dataset destination (e.g., `tank/media`) |
| `SSH_KEY` | `/root/.ssh/id_rsa` | Path to SSH key inside container |
| `SSH_CIPHER` | `chacha20-poly1305@openssh.com` | SSH cipher to use |
| `MBUFFER_SIZE` | `1G` | mbuffer size for transfers |
| `MAX_RETRIES` | `3` | Number of retry attempts |

### Volume Mounts

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| `/path/to/ssh/key` | `/root/.ssh/id_rsa:ro` | SSH private key (read-only) |
| `/dev/zfs` | `/dev/zfs` | ZFS device (required for ZFS operations) |

## Kubernetes CronJob

Deploy as a Kubernetes CronJob for scheduled syncs.

### Example CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nsyncd
  namespace: default
spec:
  schedule: "*/15 * * * *"  # Every 15 minutes
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 3
      template:
        spec:
          hostPID: true
          restartPolicy: OnFailure
          containers:
            - name: syncoid
              image: <REGISTRY>/nsyncd:latest
              envFrom:
                - configMapRef:
                    name: syncoid-config
              env:
                - name: REMOTE_HOST
                  valueFrom:
                    secretKeyRef:
                      name: nsyncd-secret
                      key: REMOTE_HOST
              volumeMounts:
                - name: ssh-key
                  mountPath: /root/.ssh/id_rsa
                  subPath: id_rsa
                  readOnly: true
                - name: dev-zfs
                  mountPath: /dev/zfs
              securityContext:
                privileged: true
          volumes:
            - name: ssh-key
              secret:
                secretName: nsyncd-secret
                defaultMode: 0600
            - name: dev-zfs
              hostPath:
                path: /dev/zfs
                type: CharDevice
```

### Example ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: syncoid-config
  namespace: default
data:
  REMOTE_USER: "<SSH_USERNAME>"
  REMOTE_PORT: "<SSH_PORT>"
  REMOTE_DATASET: "<REMOTE_ZFS_DATASET>"
  LOCAL_DATASET: "<LOCAL_ZFS_DATASET>"
  SSH_KEY: "/root/.ssh/id_rsa"
  SSH_CIPHER: "chacha20-poly1305@openssh.com"
  MBUFFER_SIZE: "1G"
  MAX_RETRIES: "3"
```

### Prerequisites

- Node with ZFS installed and pool imported
- Privileged namespace (Pod Security Admission)
- External Secrets Operator (optional, for secret management)

### Deploy

```bash
kubectl apply -f cronjob.yaml
kubectl apply -f configmap.yaml
```

### Trigger Manual Sync

```bash
kubectl create job --from=cronjob/nsyncd nsyncd-manual -n default
```

## Logs

```bash
# View latest job logs
kubectl logs -l app=nsyncd -n default --tail=100

# Follow a specific job
kubectl logs job/nsyncd-manual -n default -f
```

## Customizing the Schedule

Modify the `schedule` field in the CronJob:

```yaml
schedule: "*/15 * * * *"  # Every 15 minutes
schedule: "0 * * * *"     # Every hour
schedule: "0 */6 * * *"   # Every 6 hours
schedule: "0 0 * * *"     # Daily at midnight
```

## Troubleshooting

### SSH Connection Issues

```bash
# Test from a running job pod
kubectl exec -it job/nsyncd-manual -n default -- \
  ssh -i /root/.ssh/id_rsa -p <SSH_PORT> <SSH_USERNAME>@<REMOTE_HOST_IP>
```

### ZFS Issues

```bash
# Check ZFS is accessible in pod
kubectl exec -it job/nsyncd-manual -n default -- zpool list
kubectl exec -it job/nsyncd-manual -n default -- zfs list
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `failed to initialize ZFS library` | `/dev/zfs` not mounted | Add hostPath volume for `/dev/zfs` |
| `No such pool` | ZFS pool not imported on node | Import pool on the node |
| `No matching snapshots` | No common snapshot between source/destination | See "Initial Sync" section |

### Initial Sync

For the first sync, syncoid needs a common snapshot on both sides. If syncing to an existing dataset, ensure at least one snapshot exists on both with matching GUIDs (created via `zfs send/receive`, not independently).

## File Structure

```
├── Dockerfile    # Container image definition
├── sync.sh       # Syncoid sync script
└── README.md     # This file
```
