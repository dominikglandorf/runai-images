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

    SCRATCH=data
    if [ -d "/$SCRATCH" ]; then
        # Mounted on /dlabscratch1/$SCRATCH -> set home and do nothing
        USER_HOME=/$SCRATCH/$GASPAR_USER
    else
        # No scratch mounted -> create home in /home
        USER_HOME=/home/${GASPAR_USER}
        mkdir -p $USER_HOME
    fi

    # Create User and add to groups
    useradd -u ${GASPAR_UID} -d $USER_HOME -s /bin/bash ${GASPAR_USER} -g ${GASPAR_GID}     
    usermod -aG $(echo $GASPAR_SUPG | tr ' ' ',') ${GASPAR_USER}
    if ! [ -d "$SCRATCH" ]; then
        chown -R ${GASPAR_USER}:${GASPAR_GID} $USER_HOME
    fi

    # passwordless sudo
    echo "${GASPAR_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    # HACKYYYY: set automatic bash login 
    echo "exec gosu ${GASPAR_USER} /bin/bash" > /root/.bashrc


    # .bashrc for user
    chown ${GASPAR_USER}:${GASPAR_GID} /tmp/.bashrc
    su ${GASPAR_USER} -c "if [ ! -f "$USER_HOME/.bashrc" ]; then cp /tmp/.bashrc '$USER_HOME/.bashrc'; fi"
fi


# Find correct USER_HOME if it's undefined
if [ -z "$USER_HOME" ]; then
    if [ -d "/mnt/scratch/$GASPAR_USER" ]; then
        USER_HOME="/mnt/scratch/$GASPAR_USER"
    elif [ -d "/home/$GASPAR_USER" ]; then
        USER_HOME="/home/$GASPAR_USER"
    else
        echo "Error: Unable to find a valid home directory for $GASPAR_USER"
        exit 1
    fi
fi

echo "USER_HOME: $USER_HOME"


if [ -z "$1" ]; then
    exec gosu ${GASPAR_USER} /bin/bash -c "source ~/.bashrc && exec /bin/bash"
else
    echo "**** Executing '/bin/bash -c \"$*\"' ****"
    exec gosu ${GASPAR_USER} /bin/bash -c "source ~/.bashrc && exec /bin/bash -c \"$*\""
fi
