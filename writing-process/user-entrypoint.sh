#!/bin/sh

set -e

# start sshd
service ssh start

# Setup GASPAR USER
GASPAR_USER=$(awk -F '-' '{ print $3 }' /var/run/secrets/kubernetes.io/serviceaccount/namespace)

if ! id -u $GASPAR_USER > /dev/null 2>&1; then
    echo "**** Creating GASPAR USER ****"
    GASPAR_UID=$(ldapsearch -H ldap://scoldap.epfl.ch -x -b "ou=users,o=epfl,c=ch" "(uid=$GASPAR_USER)" uidNumber | egrep ^uidNumber | awk '{ print $2 }')
    GASPAR_GID=$(ldapsearch -H ldap://scoldap.epfl.ch -x -b "ou=users,o=epfl,c=ch" "(uid=$GASPAR_USER)" gidNumber | egrep ^gidNumber | awk '{ print $2 }')
    GASPAR_SUPG=$(ldapsearch -LLL -H ldap://scoldap.epfl.ch -x -b ou=groups,o=epfl,c=ch \(memberUid=${GASPAR_USER}\) gidNumber | grep 'gidNumber:' | awk '{ print $2 }' | paste -s -d' ' -)

    echo "**** Create groups ****"
    # Create Groups
    for gid in $GASPAR_SUPG; do
        GROUP_NAME=$(ldapsearch -LLL -H ldap://scoldap.epfl.ch -x \
            -b ou=groups,o=epfl,c=ch "(gidNumber=$gid)" cn | awk '/^cn:/ {print $2}')

        # If the name is longer than 32 chars, shorten deterministically
        if [ ${#GROUP_NAME} -gt 32 ]; then
            # Keep first 24 chars, append 8-char hash to avoid collisions
            GRPNM=$(echo "$GROUP_NAME" | cut -c1-29)
        else
            GRPNM=$GROUP_NAME
        fi

        if ! getent group "$GRPNM" > /dev/null 2>&1; then
            groupadd -g "$gid" "$GRPNM"
        else
            groupmod -g "$gid" "$GRPNM"

        fi
    done

    # additionally create a user-owned home on the container FS
    mkdir -p /home/${GASPAR_USER}

    echo "**** Set user_home ****"
    SCRATCH=data
    if [ -d "/$SCRATCH" ]; then
        # Mounted on /data/$SCRATCH -> set home and do nothing
        USER_HOME=/$SCRATCH/$GASPAR_USER
        echo "**** USER_HOME set to $USER_HOME ****"
    else
        USER_HOME=/home/${GASPAR_USER}
    fi

    # Create User and add to groups
    useradd -u ${GASPAR_UID} -d $USER_HOME -s /bin/bash ${GASPAR_USER} -g ${GASPAR_GID}     
    usermod -aG $(echo $GASPAR_SUPG | tr ' ' ',') ${GASPAR_USER}

    chown -R ${GASPAR_USER}:${GASPAR_GID} /home/${GASPAR_USER}

    # passwordless sudo
    echo "${GASPAR_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# Find correct USER_HOME if it's undefined
if [ -z "$USER_HOME" ]; then
    if [ -d "/data/$GASPAR_USER" ]; then
        USER_HOME="/data/$GASPAR_USER"
    elif [ -d "/home/$GASPAR_USER" ]; then
        USER_HOME="/home/$GASPAR_USER"
    else
        echo "Error: Unable to find a valid home directory for $GASPAR_USER"
        exit 1
    fi
fi

echo "USER_HOME: $USER_HOME"

USER_HOME=$USER_HOME gosu ${GASPAR_USER} bash -c 'REQ="$USER_HOME/anoush-spring-26/requirements.txt"
echo [ -f "$REQ" ]
if [ -f "$REQ" ]; then
    echo "**** Installing requirements from $REQ ****"
    pip install -r "$REQ"
    pip install -e "$USER_HOME/anoush-spring-26/."
fi'

exec gosu ${GASPAR_USER} /bin/bash -c "$*"