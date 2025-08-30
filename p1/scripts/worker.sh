apk update
apk add curl

TOKEN_FILE="/vagrant/token"
SERVER_IP="192.168.56.110"

while [ ! -f "$TOKEN_FILE" ]; do
     sleep 2
     echo "Waiting for token file..."
     echo "$(cat $TOKEN_FILE 2>/dev/null)"
done

TOKEN=$(cat "$TOKEN_FILE")

curl -sfL https://get.k3s.io | K3S_URL="https://$SERVER_IP:6443" K3S_TOKEN="$TOKEN" sh -