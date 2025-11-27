ARG PLATFORM=linux/amd64
FROM --platform=${PLATFORM} pytorch/pytorch:2.7.1-cuda12.6-cudnn9-devel

USER root
# Switch all Ubuntu ports URLs from HTTP → HTTPS
# RUN sed -i 's|http://ports.ubuntu.com|https://ports.ubuntu.com|g' /etc/apt/sources.list \
#  && sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g' /etc/apt/sources.list

# Install system dependencies, and SSH server
RUN apt-get update && apt-get install -y --no-install-recommends  \
        curl \
        gcc \
        git  \
        gosu \
        htop \
        ldap-utils \
        nano \
        wget ca-certificates \
        libglib2.0-0 libxext6 libsm6 libxrender1 \
        sudo build-essential curl \
        libcurl4-openssl-dev  \
        tmux \
        zip unzip openssh-server zsh \
        libgl1-mesa-glx pkg-config


EXPOSE 22

COPY discoagents/user-entrypoint.sh /tmp/user-entrypoint.sh
RUN chmod +x /tmp/user-entrypoint.sh
ENTRYPOINT ["/tmp/user-entrypoint.sh"]


CMD ["sleep infinity"]