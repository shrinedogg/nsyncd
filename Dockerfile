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
    && rm -rf /var/lib/apt/lists/*

# Create directory for SSH key
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Create the sync script
COPY sync.sh /usr/local/bin/sync.sh
RUN chmod +x /usr/local/bin/sync.sh

ENTRYPOINT ["/usr/local/bin/sync.sh"]
