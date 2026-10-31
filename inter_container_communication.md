# 5. Inter-Container Communication

```mermaid
sequenceDiagram
    participant UE as UE (10.53.1.4)
    participant GNB as gNB (10.53.1.3)
    participant CORE as Core (10.53.1.2)
    participant DB as MongoDB (10.53.1.20)
    participant NET as Internet

    GNB->>UE: ZMQ TCP:2000 (Downlink I/Q)
    UE->>GNB: ZMQ TCP:2001 (Uplink I/Q)
    GNB<<->>CORE: NGAP/SCTP:38412 to AMF (Control plane)
    GNB<<->>CORE: GTP-U/UDP:2152 to UPF (User plane tunnel)
    Note over CORE: ogstun (10.45.0.1)
    CORE<<->>NET: NAT
    CORE<<->>DB: TCP:27017
```

| Link | Protocol | Port | Direction | Carries |
| :--- | :--- | :--- | :--- | :--- |
| UE ↔ gNB (DL) | ZMQ/TCP | 2000 | gNB → UE | Downlink I/Q radio samples |
| UE ↔ gNB (UL) | ZMQ/TCP | 2001 | UE → gNB | Uplink I/Q radio samples |
| gNB ↔ AMF | NGAP/SCTP | 38412 | Bidirectional | Control signaling (registration, session setup) |
| gNB ↔ UPF | GTP-U/UDP | 2152 | Bidirectional | Tunneled UE data packets |
| Core ↔ MongoDB | TCP | 27017 | Bidirectional | Subscriber record queries |
| UPF ↔ Internet | NAT | — | Bidirectional | UE traffic after GTP-U decapsulation |
