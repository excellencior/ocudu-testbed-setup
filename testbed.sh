#!/usr/bin/env bash
# ==============================================================================
# 5G SA Containerized Testbed Management Script
# Architecture: Open5GS (5GC) + MongoDB + OCUDU (gNB) + srsUE (simulated UE)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

usage() {
    cat <<EOF
Usage: ./testbed.sh <command>

Commands:
  start       Start all 5G testbed containers in order (DB -> Core -> gNB -> UE)
  stop        Stop all 5G testbed containers
  restart     Restart the testbed cleanly in proper dependency sequence
  status      Show the status of all testbed containers and IP allocations
  ping        Run ping test from the simulated UE to the 5G UPF gateway (10.45.0.1)
  iperf-ul    Run uplink throughput test from UE to Core (10s)
  iperf-dl    Run downlink throughput test from Core to UE (10s)
  logs [svc]  View logs of a service (mongodb, open5gs, ocudu-gnb, srs-ue)
EOF
    exit 1
}

cmd_start() {
    echo "=== [1/4] Starting MongoDB ==="
    docker compose up -d mongodb
    sleep 2

    echo "=== [2/4] Starting Open5GS Core ==="
    docker compose up -d open5gs
    sleep 4

    echo "=== [3/4] Starting OCUDU gNodeB ==="
    docker compose up -d ocudu-gnb
    sleep 3

    echo "=== [4/4] Starting srsUE Simulated UE ==="
    docker compose up -d srs-ue
    sleep 3

    echo "=== Testbed Started Successfully ==="
    cmd_status
}

cmd_stop() {
    echo "Stopping testbed containers..."
    docker compose stop srs-ue ocudu-gnb open5gs mongodb
    echo "All containers stopped."
}

cmd_restart() {
    echo "=== Restarting 5G Testbed ==="
    docker compose stop srs-ue ocudu-gnb
    sleep 1
    docker compose up -d ocudu-gnb
    sleep 3
    docker compose up -d srs-ue
    sleep 3
    cmd_status
}

cmd_status() {
    echo "------------------------------------------------------------"
    echo "Container Status:"
    docker compose ps
    echo "------------------------------------------------------------"
    echo "Simulated UE IP Address:"
    docker exec 5g_srs_ue ip addr show dev tun_srsue 2>/dev/null || echo "UE TUN device not up yet."
    echo "------------------------------------------------------------"
}

cmd_ping() {
    echo "=== Testing ICMP connectivity over 5G Link (UE -> UPF 10.45.0.1) ==="
    docker exec 5g_srs_ue ping -c 4 -I tun_srsue 10.45.0.1
}

cmd_iperf_ul() {
    echo "=== Ensuring iperf3 server is running in Open5GS Core ==="
    docker exec -d 5g_open5gs iperf3 -s -B 10.45.0.1 2>/dev/null || true
    sleep 1
    echo "=== Running Uplink Throughput Test (UE -> UPF) ==="
    docker exec 5g_srs_ue iperf3 -c 10.45.0.1 -B 10.45.0.2 -t 10 -i 1
}

cmd_iperf_dl() {
    echo "=== Ensuring iperf3 server is running in Open5GS Core ==="
    docker exec -d 5g_open5gs iperf3 -s -B 10.45.0.1 2>/dev/null || true
    sleep 1
    echo "=== Running Downlink Throughput Test (UPF -> UE) ==="
    docker exec 5g_srs_ue iperf3 -c 10.45.0.1 -B 10.45.0.2 -R -t 10 -i 1
}

cmd_logs() {
    local svc="$1"
    if [ -z "${svc}" ]; then
        docker compose logs --tail 30
    else
        docker compose logs --tail 50 "${svc}"
    fi
}

case "$1" in
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    restart)  cmd_restart ;;
    status)   cmd_status ;;
    ping)     cmd_ping ;;
    iperf-ul) cmd_iperf_ul ;;
    iperf-dl) cmd_iperf_dl ;;
    logs)     shift; cmd_logs "$@" ;;
    *)        usage ;;
esac
