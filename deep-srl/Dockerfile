ARG PLATFORM=linux/amd64
FROM --platform=${PLATFORM} pytorch/pytorch:2.8.0-cuda12.6-cudnn9-runtime

USER root

# Install system dependencies, and SSH server
RUN set -eux; \
    sed -i 's|http://|https://|g' /etc/apt/sources.list; \
    apt-get update && apt-get install -y --no-install-recommends  \
        curl \
        git  \
        gosu \
        ldap-utils \
        nano \
        openssh-server \ 
        zip \
        sudo

EXPOSE 22

COPY requirements.txt tmp/requirements.txt
RUN /opt/conda/bin/python -m pip install --upgrade pip
RUN /opt/conda/bin/pip install -r tmp/requirements.txt
RUN chmod -R 777 /opt/conda/bin/ /opt/conda/lib/ 

COPY user-entrypoint.sh /tmp/user-entrypoint.sh
RUN chmod +x /tmp/user-entrypoint.sh
ENTRYPOINT ["/tmp/user-entrypoint.sh"]

CMD ["sleep infinity"]