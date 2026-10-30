# OCUDU 5G SA Testbed — Dockerized Setup

A fully containerized 5G Standalone (SA) testbed using [OCUDU](https://github.com/softwareradiosystems/ocudu) as the gNodeB, Open5GS as the 5G Core, and srsRAN 4G's srsUE as the simulated UE. All communication uses ZeroMQ virtual radio — no RF hardware required.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     Docker Network: ran_net (10.53.1.0/24)               │
│                                                                          │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────┐    ┌────────────┐  │
│  │ MongoDB  │    │   Open5GS    │    │  OCUDU gNB   │    │   srsUE    │  │
│  │          │◄───│  5G Core     │◄───│  Base Station │◄──►│  Sim. UE   │  │
│  │10.53.1.20│    │  10.53.1.2   │    │  10.53.1.3   │    │ 10.53.1.4  │  │
│  │          │    │              │    │              │    │            │  │
│  │ Subscriber│    │ AMF,SMF,UPF │    │ ZMQ RF port  │    │ ZMQ RF port│  │
│  │ Database  │    │ NRF,AUSF,.. │    │   TX: 2000   │    │  TX: 2001  │  │
│  └──────────┘    │              │    └──────────────┘    └────────────┘  │
│                  │   ogstun:    │                                        │
│                  │  10.45.0.1   │─── UE PDU Session IP: 10.45.0.2       │
│                  └──────────────┘                                        │
└──────────────────────────────────────────────────────────────────────────┘
```

| Container | IP | Image | Role |
|-----------|------|-------|------|
| `5g_mongodb` | `10.53.1.20` | `mongo:6.0` | Subscriber database (standalone) |
| `5g_open5gs` | `10.53.1.2` | Built from source (v2.7.6) | 5G Core — all NFs |
| `5g_ocudu_gnb` | `10.53.1.3` | Built from OCUDU source | gNodeB with ZMQ virtual radio |
| `5g_srs_ue` | `10.53.1.4` | Built from srsRAN_4G | Simulated UE with ZMQ |

## Prerequisites

- Docker Engine ≥ 20.10
- Docker Compose v2
- Git
- ~10 GB disk space (for building images)
- Internet connection (for cloning repos and pulling base images)

## Setup

### 1. Clone this repository

```bash
git clone git@github.com:excellencior/ocudu-testbed-setup.git
cd ocudu-testbed-setup
```

### 2. Clone the OCUDU repository

OCUDU source is required to build the gNB image. Clone it into the project root:

```bash
git clone https://github.com/softwareradiosystems/ocudu.git
```

The `ocudu/` directory is gitignored — it's pulled separately so this repo doesn't redistribute the OCUDU source.

### 3. Build Docker images

**Build all three images** (Open5GS takes ~10-15 minutes on first build, OCUDU and srsUE ~5 minutes each):

```bash
# Build Open5GS 5G Core (from source, v2.7.6)
docker compose build open5gs

# Build OCUDU gNodeB (requires ocudu/ directory from Step 2)
docker build -t ocudu-gnb:latest -f docker/Dockerfile.ocudu .

# Build srsUE (clones srsRAN_4G automatically)
docker build -t srs-ue:latest -f docker/Dockerfile.srsue .
```

> **Note**: After the first build, Docker layer caching makes subsequent builds near-instant unless you modify the Dockerfiles.

### 4. Start the testbed

```bash
./testbed.sh start
```

This starts containers in dependency order: MongoDB → Open5GS → gNB → UE, with appropriate delays between each.

### 5. Verify connectivity

```bash
# Check container status and UE TUN interface
./testbed.sh status

# Ping test: UE → UPF gateway (over the 5G link)
./testbed.sh ping

# Throughput test: Uplink (UE → Core)
./testbed.sh iperf-ul

# Throughput test: Downlink (Core → UE)
./testbed.sh iperf-dl
```

A successful ping to `10.45.0.1` confirms the full 5G SA data path is working:
UE → ZMQ → gNB → GTP-U → UPF → ogstun → reply.

## Management

```bash
./testbed.sh start       # Start all containers in order
./testbed.sh stop        # Stop all containers
./testbed.sh restart     # Restart gNB + UE (keeps Core/DB running)
./testbed.sh status      # Container status + UE IP
./testbed.sh ping        # ICMP test over 5G
./testbed.sh iperf-ul    # Uplink throughput
./testbed.sh iperf-dl    # Downlink throughput
./testbed.sh logs [svc]  # View logs (mongodb, open5gs, ocudu-gnb, srs-ue)
```

## Project Structure

```
.
├── docker-compose.yml              # Orchestrates all 4 containers
├── testbed.sh                      # CLI management script
├── .gitignore
├── .dockerignore
│
├── docker/
│   ├── Dockerfile.open5gs          # 5G Core — builds Open5GS v2.7.6 from source
│   ├── Dockerfile.ocudu            # gNB — builds OCUDU with ZMQ support
│   └── Dockerfile.srsue            # UE — builds srsRAN_4G srsUE with ZMQ
│
├── configs/
│   ├── open5gs-5gc.yml             # Unified 5GC config template (envsubst)
│   ├── open5gs_entrypoint.sh       # 5GC container entrypoint
│   ├── setup_tun.py                # TUN interface + NAT setup (pyroute2/nftables)
│   ├── add_users.py                # Subscriber provisioning (OCUDU official)
│   ├── gnb_zmq.yaml                # gNB radio config (ZMQ, 10 MHz, Band 7 FDD)
│   └── ue_zmq.conf                 # UE radio config (ZMQ, IMSI, K/OPc)
│
└── ocudu/                          # (gitignored) Clone of OCUDU source repo
```

## Configuration Details

### Network

| Parameter | Value | Configured in |
|-----------|-------|---------------|
| Docker subnet | `10.53.1.0/24` | `docker-compose.yml` |
| UE IP pool | `10.45.0.0/24` | `open5gs-5gc.yml` (`UE_IP_BASE`) |
| UE gateway | `10.45.0.1` | `ogstun` interface on UPF |
| GTP-U port | `UDP 2152` | Standard (gNB ↔ UPF) |
| ZMQ DL port | `TCP 2000` | `gnb_zmq.yaml` (gNB TX) |
| ZMQ UL port | `TCP 2001` | `ue_zmq.conf` (UE TX) |

### Radio

| Parameter | Value | Why |
|-----------|-------|-----|
| Band | 7 FDD (2620 MHz DL / 2500 MHz UL) | Standard OCUDU test band |
| Bandwidth | 10 MHz | ZMQ CPU stability (20 MHz causes timing issues) |
| Sample rate | 11.52 Msps | Matches 10 MHz NR bandwidth |
| Subcarrier spacing | 15 kHz | NR numerology 0 (FDD) |

### Subscriber (Soft SIM)

| Parameter | Value |
|-----------|-------|
| IMSI | `001010123456780` |
| MCC/MNC | `001/01` |
| Key (K) | `00112233445566778899aabbccddeeff` |
| OPc | `63bfa50ee6523365ff14c1f45f88737d` |
| AMF | `8000` |
| APN/DNN | `internet` |
| Static IP | `10.45.0.2` |
| QCI | `9` |

To change subscriber data without rebuilding, edit the `SUBSCRIBER_DB` env var in `docker-compose.yml`.
Format: `IMSI,K,op_type,OPc,AMF,QCI,IP`

### What Differs from OCUDU's Official Docker Setup

| Aspect | OCUDU Official | This Testbed |
|--------|---------------|-------------|
| MongoDB | Embedded inside 5GC container | Standalone container (`10.53.1.20`) |
| WebUI | Included (Node.js) | Skipped (subscribers provisioned via `add_users.py`) |
| srsUE | Not provided | Added as 4th container |
| Bandwidth | 20 MHz / 23.04 Msps | 10 MHz / 11.52 Msps (ZMQ stability) |
| RF driver | USRP B210 + UHD | ZeroMQ virtual radio |

## Troubleshooting

### UE can't attach

```bash
# Check gNB logs for NGAP/RRC issues
./testbed.sh logs ocudu-gnb

# Check UE logs for RACH/NAS issues
./testbed.sh logs srs-ue

# Verify AMF is listening
docker exec 5g_open5gs ss -tlnp | grep 38412
```

### No PDU session

```bash
# Verify subscriber exists in MongoDB
docker exec 5g_mongodb mongosh --eval 'db.getSiblingDB("open5gs").subscribers.find().pretty()'

# Check SMF logs
docker exec 5g_open5gs cat /open5gs/install/var/log/open5gs/smf.log 2>/dev/null || \
  docker logs 5g_open5gs 2>&1 | grep -i smf
```

### Ping fails after UE attaches

```bash
# Verify ogstun exists and has correct IP
docker exec 5g_open5gs ip addr show ogstun

# Verify NAT rules
docker exec 5g_open5gs nft list ruleset

# Verify UE has tun_srsue interface
docker exec 5g_srs_ue ip addr show tun_srsue
```

## License

The testbed configuration files in this repository are provided as-is. OCUDU, Open5GS, and srsRAN_4G each have their own licenses — refer to their respective repositories.
