ARG PLATFORM=linux/amd64
FROM --platform=${PLATFORM} pytorch/pytorch:2.7.1-cuda12.6-cudnn9-devel

USER root
# Install system dependencies, and SSH server
RUN apt-get update && \
   apt-get install -y  --no-install-recommends  \
        curl \
        gcc \
        git  \
        gosu \
        nano \
        wget ca-certificates \
        libglib2.0-0 libxext6 libsm6 libxrender1 \
        
        sudo build-essential curl \
        libcurl4-openssl-dev  \
        tmux \
        zip unzip openssh-server zsh \
        libgl1-mesa-glx pkg-config

# install Miniforge
RUN wget -O /tmp/Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" && \
    bash /tmp/Miniforge3.sh -b -p "/opt/conda" &&  rm /tmp/Miniforge3.sh
RUN . /opt/conda/etc/profile.d/conda.sh
# make conda install writable
RUN chmod -R 777 /opt/conda

EXPOSE 22

COPY base/user-entrypoint.sh /tmp/user-entrypoint.sh
RUN chmod +x /tmp/user-entrypoint.sh
ENTRYPOINT ["/tmp/user-entrypoint.sh"]


CMD ["sleep infinity"]