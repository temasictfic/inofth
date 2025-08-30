#!/bin/bash

apk update
apk add curl

curl -sfL https://get.k3s.io | sh -

TOKEN_PATH="/vagrant/token"

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
    sleep 2
    echo "Waiting for k3s to initialize..."
done

cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_PATH"

chmod 777 "$TOKEN_PATH"