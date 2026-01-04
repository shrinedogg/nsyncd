FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages including ZFS utilities
RUN apt-get update && apt-get install -y \
    sanoid \
    zfsutils-linux \
    openssh-client \
    mbuffer \
    pv \
    lzop \
    zstd \
    cron \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create directory for SSH key
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Create the sync script
COPY sync.sh /usr/local/bin/sync.sh
RUN chmod +x /usr/local/bin/sync.sh

# Create the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set up cron job to run every 15 minutes (output to stdout/stderr via /proc)
RUN echo "*/15 * * * * /usr/local/bin/sync.sh > /proc/1/fd/1 2>/proc/1/fd/2" > /etc/cron.d/syncoid-cron \
    && chmod 0644 /etc/cron.d/syncoid-cron \
    && crontab /etc/cron.d/syncoid-cron

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
