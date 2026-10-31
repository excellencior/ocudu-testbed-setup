#!/bin/bash
# open5gs_entrypoint.sh — Following OCUDU's official entrypoint pattern
# Reference: ocudu/docker/open5gs/open5gs_entrypoint.sh
#
# Key difference: MongoDB runs as a standalone container (not embedded),
# so we skip "mongod &" and "webui" startup.

set -e

echo "=== [Open5GS] Starting 5G Core Initialization ==="

# 1. Compute derived environment variables
export UE_GATEWAY_IP="${UE_IP_BASE}.1"
export UE_IP_RANGE="${UE_IP_BASE}.0/24"

# 2. Detect architecture for freeDiameter library paths
INSTALL_ARCH=x86_64-linux-gnu
if [ "$(uname -m)" = "aarch64" ]; then
    INSTALL_ARCH="aarch64-linux-gnu"
fi
export INSTALL_ARCH

# 3. Process config template with envsubst (official approach)
#    Replaces ${MONGODB_IP}, ${MCC}, ${MNC}, ${OPEN5GS_IP}, etc.
envsubst < open5gs-5gc.yml.in > open5gs-5gc.yml
echo "Config template processed."

# 4. Create dummy loopback interfaces for Open5GS NF bindings (official pattern)
#    Each NF binds to a different 127.0.0.x address
for IP in {2..22}
do
    ip link add name lo$IP type dummy
    ip ad ad 127.0.0.$IP/24 dev lo$IP
    ip link set lo$IP up
done
echo "Loopback interfaces created."

# 5. (SKIP) MongoDB is a standalone container — no embedded mongod needed
#    Official entrypoint runs: mkdir -p /data/db && mongod --logpath /tmp/mongodb.log &

# 6. Wait for external MongoDB to become ready
MONGODB_HOST="${MONGODB_IP:-10.53.1.20}"
echo "Waiting for MongoDB at ${MONGODB_HOST}:27017..."
while ! ( nc -zv $MONGODB_HOST 27017 2>&1 >/dev/null )
do
    echo "  waiting for mongodb..."
    sleep 1
done
echo "MongoDB connection established."

# 7. Setup ogstun and routing (official setup_tun.py with pyroute2 + nftables)
python3 setup_tun.py --ip_range ${UE_IP_RANGE}
if [ $? -ne 0 ]
then
    echo "Failed to setup ogstun and routing"
    exit 1
fi
echo "TUN interface and NAT configured."

# 8. Provision subscriber data from YAML file or env var fallback
SUBSCRIBERS_FILE="/open5gs/subscribers.yml"
if [ -f "${SUBSCRIBERS_FILE}" ]; then
    echo "Loading subscribers from ${SUBSCRIBERS_FILE}..."
    python3 add_users.py --mongodb ${MONGODB_HOST} --subscriber_data "${SUBSCRIBERS_FILE}"
    if [ $? -ne 0 ]; then
        echo "Failed to add subscribers from YAML"
        exit 1
    fi
elif [ -n "${SUBSCRIBER_DB}" ]; then
    echo "Loading subscriber from SUBSCRIBER_DB env var..."
    python3 add_users.py --mongodb ${MONGODB_HOST} --subscriber_data "${SUBSCRIBER_DB}"
    if [ $? -ne 0 ]; then
        echo "Failed to add subscribers to database"
        exit 1
    fi
else
    echo "WARNING: No subscriber data found (no YAML file or SUBSCRIBER_DB env var)"
fi
echo "Subscriber provisioning complete."

# 9. (SKIP) WebUI — not needed, subscribers provisioned via add_users.py
#    Official entrypoint runs: cd webui && npm run dev &

# 10. Start Open5GS 5GC (passed as CMD from docker-compose: "5gc -c open5gs-5gc.yml")
echo "=== [Open5GS] Core is fully operational ==="
exec stdbuf -o L $@
