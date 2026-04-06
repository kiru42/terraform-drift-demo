# Visual Configuration Guide

> **Visual learning guide** with diagrams, flowcharts, and examples.

---

## Table of Contents

1. [Traffic Flow Diagrams](#traffic-flow-diagrams)
2. [Security Rule Decision Tree](#security-rule-decision-tree)
3. [Common Network Topologies](#common-network-topologies)
4. [Security Profiles Stack](#security-profiles-stack)
5. [NAT Scenarios](#nat-scenarios)
6. [Zone-Based Architecture](#zone-based-architecture)

---

## Traffic Flow Diagrams

### How Firewall Processes Traffic

```
┌─────────────────────────────────────────────────────────────┐
│                     Incoming Packet                         │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ↓
                ┌────────────────────────┐
                │  1. Zone Determination │
                │     (ingress zone)     │
                └───────────┬────────────┘
                            │
                            ↓
                ┌────────────────────────┐
                │  2. NAT Policy Lookup  │
                │  (if applicable)       │
                └───────────┬────────────┘
                            │
                            ↓
                ┌────────────────────────┐
                │  3. Security Rule      │
                │     Match (top-down)   │
                └───────────┬────────────┘
                            │
                    ┌───────┴────────┐
                    │                │
                  Allow             Deny
                    │                │
                    ↓                ↓
        ┌────────────────────┐   ┌──────────┐
        │ 4. Security        │   │  Drop    │
        │    Profiles        │   │  Packet  │
        │    - App-ID        │   └──────────┘
        │    - Antivirus     │
        │    - Anti-Spyware  │
        │    - Vulnerability │
        │    - URL Filter    │
        │    - File Block    │
        │    - Data Filter   │
        │    - WildFire      │
        └─────────┬──────────┘
                  │
                  ↓
        ┌────────────────────┐
        │ 5. QoS Marking     │
        │    (if configured) │
        └─────────┬──────────┘
                  │
                  ↓
        ┌────────────────────┐
        │ 6. Logging         │
        │    (if enabled)    │
        └─────────┬──────────┘
                  │
                  ↓
        ┌────────────────────┐
        │ 7. Forward Packet  │
        │    (to egress zone)│
        └────────────────────┘
```

---

## Security Rule Decision Tree

### Should I Allow or Deny This Traffic?

```
                          ┌─────────────────┐
                          │  Start: New     │
                          │  Traffic Flow   │
                          └────────┬────────┘
                                   │
                                   ↓
                          ┌─────────────────┐
                          │ Is source from  │
                          │ trusted zone?   │
                          └────┬───────┬────┘
                               │       │
                             YES      NO
                               │       │
                               ↓       ↓
                    ┌──────────────┐  ┌──────────────┐
                    │ Is destination│  │ Likely block │
                    │ allowed for   │  │ (untrusted → │
                    │ this source?  │  │  internal)   │
                    └───┬───────┬───┘  └──────────────┘
                        │       │
                      YES      NO
                        │       │
                        ↓       ↓
            ┌────────────────┐ ┌────────────────┐
            │ Is application │ │ Block & log    │
            │ business-      │ │ (policy deny)  │
            │ appropriate?   │ └────────────────┘
            └───┬────────┬───┘
                │        │
              YES       NO
                │        │
                ↓        ↓
    ┌──────────────────┐ ┌──────────────────┐
    │ Apply security   │ │ Block risky app  │
    │ profiles:        │ │ (P2P, Tor, etc.) │
    │ - AV             │ └──────────────────┘
    │ - AS             │
    │ - Vuln           │
    │ - URL Filter     │
    │ - File Block     │
    │ - DLP            │
    │ - WildFire       │
    └────────┬─────────┘
             │
             ↓
    ┌──────────────────┐
    │ Allow + log      │
    │ (deep inspect)   │
    └──────────────────┘
```

---

## Common Network Topologies

### 1. Simple Office Network

```
                    Internet
                       │
                       │ (untrust zone)
                       ↓
              ┌────────────────┐
              │   Firewall     │
              │   (PA-5220)    │
              └────────┬───────┘
                       │ (trust zone)
                       │
          ┌────────────┼────────────┐
          │            │            │
    ┌─────▼─────┐ ┌───▼────┐ ┌────▼─────┐
    │ Employees │ │ Servers│ │ Printers │
    │ 10.0.1.0/ │ │10.0.2.0│ │10.0.3.0/ │
    │    24     │ │  /24   │ │    24    │
    └───────────┘ └────────┘ └──────────┘

Rules needed:
1. Allow: trust → untrust (web, email)
2. Allow: trust → servers (internal apps)
3. Block: untrust → trust (all inbound)
```

### 2. DMZ Architecture

```
                    Internet
                       │
                       │ (untrust)
                       ↓
              ┌────────────────┐
              │   Firewall     │
              │                │
              └─┬─────────┬────┘
                │         │
      (trust)   │         │  (dmz)
                │         │
         ┌──────▼───┐  ┌──▼─────────┐
         │ Internal │  │ Web Server │
         │  Users   │  │ (public)   │
         │10.0.0.0/8│  │10.100.10.0/│
         └──────────┘  │    24      │
                       └────────┬───┘
                                │
                         ┌──────▼─────┐
                         │  Database  │
                         │ (backend)  │
                         │10.200.20.0/│
                         │    24      │
                         └────────────┘

Rules needed:
1. Allow: trust → untrust (internet)
2. Allow: trust → dmz:443 (internal → web)
3. Allow: dmz → database:3306 (web → db)
4. Allow: untrust → dmz:443 (public → web)
5. Block: dmz → trust (no DMZ → internal)
6. Block: untrust → trust (no internet → internal)
```

### 3. Multi-Cloud Hybrid

```
         ┌──────────────┐        ┌──────────────┐
         │   AWS VPC    │        │  Azure VNet  │
         │  10.1.0.0/16 │        │ 10.2.0.0/16  │
         └───────┬──────┘        └──────┬───────┘
                 │                      │
                 │ VPN / Direct Connect │
                 │                      │
                 └──────┬───────────────┘
                        │
                        ↓
              ┌─────────────────┐
              │   Firewall      │
              │   (Hub/Gateway) │
              └─────────┬───────┘
                        │
              ┌─────────┼─────────┐
              │         │         │
         ┌────▼───┐ ┌───▼───┐ ┌──▼────┐
         │On-Prem │ │Branch │ │ GCP   │
         │  DC    │ │Office │ │ VPC   │
         │10.0.0.0│ │10.3.0.│ │10.4.0.│
         │  /8    │ │ 0/16  │ │ 0/16  │
         └────────┘ └───────┘ └───────┘

Rules needed:
- Cloud → Cloud: Allow specific apps
- Cloud → On-Prem: Allow with encryption
- On-Prem → Cloud: Allow cloud services
- Geo-blocking for sensitive regions
```

---

## Security Profiles Stack

### Defense in Depth Visualization

```
┌──────────────────────────────────────────────┐
│           Application Layer                  │
│  ┌────────────────────────────────────────┐  │
│  │ App-ID: Identify application           │  │
│  │  (web-browsing, ssh, office365, etc.)  │  │
│  └────────────────────────────────────────┘  │
└──────────────────┬───────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────┐
│         Threat Prevention Layer              │
│  ┌────────────────────────────────────────┐  │
│  │ 1. Antivirus (AV)                      │  │
│  │    Scan files for malware signatures   │  │
│  ├────────────────────────────────────────┤  │
│  │ 2. Anti-Spyware (AS)                   │  │
│  │    Detect C&C, botnets, DNS tunnels    │  │
│  ├────────────────────────────────────────┤  │
│  │ 3. Vulnerability Protection (IPS)      │  │
│  │    Block exploits, SQL injection, XSS  │  │
│  └────────────────────────────────────────┘  │
└──────────────────┬───────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────┐
│         Content Control Layer                │
│  ┌────────────────────────────────────────┐  │
│  │ 4. URL Filtering                       │  │
│  │    Block by website category           │  │
│  ├────────────────────────────────────────┤  │
│  │ 5. File Blocking                       │  │
│  │    Block .exe, scripts, macros         │  │
│  ├────────────────────────────────────────┤  │
│  │ 6. Data Filtering (DLP)                │  │
│  │    Prevent credit cards, SSN leaks     │  │
│  └────────────────────────────────────────┘  │
└──────────────────┬───────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────┐
│         Sandboxing Layer                     │
│  ┌────────────────────────────────────────┐  │
│  │ 7. WildFire                            │  │
│  │    Cloud sandbox for unknown files     │  │
│  │    • Forward to cloud                  │  │
│  │    • Execute in VM                     │  │
│  │    • Generate signature                │  │
│  │    • Update all firewalls globally     │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### When Each Profile Triggers

```
User Request: Download file.exe from website
        │
        ↓
┌───────────────────┐
│ 1. App-ID         │ ← Identifies: "web-browsing"
│    Matches rule   │
└────────┬──────────┘
         │
         ↓
┌───────────────────┐
│ 2. URL Filtering  │ ← Checks: Is website.com malicious?
│    Category check │    If yes → Block
└────────┬──────────┘
         │
         ↓
┌───────────────────┐
│ 3. File Blocking  │ ← Checks: Is .exe allowed?
│    Extension check│    Config: Block .exe → Block
└────────┬──────────┘
         │
         ↓
┌───────────────────┐
│ 4. Antivirus      │ ← Scans: Known malware signature?
│    Signature scan │    If match → Block
└────────┬──────────┘
         │
         ↓
┌───────────────────┐
│ 5. WildFire       │ ← Unknown file → Send to cloud
│    Sandbox        │    Execute in VM
│    analysis       │    Verdict: Malware → Block globally
└───────────────────┘
```

---

## NAT Scenarios

### Source NAT (SNAT) - Outbound

**Scenario:** Internal users (private IPs) need to access internet

```
BEFORE NAT:
┌─────────────┐                 ┌──────────┐
│ PC          │                 │ Internet │
│ 10.0.0.50   │───────────────→ │ Server   │
└─────────────┘                 │8.8.8.8   │
Source: 10.0.0.50               └──────────┘
Dest: 8.8.8.8
❌ Internet doesn't route 10.0.0.0/8 (private IP)

AFTER NAT (by firewall):
┌─────────────┐    ┌──────────┐    ┌──────────┐
│ PC          │    │Firewall  │    │ Internet │
│ 10.0.0.50   │───→│  NAT     │───→│ Server   │
└─────────────┘    │203.0.113.│    │8.8.8.8   │
                   │   50     │    └──────────┘
                   └──────────┘
Source: 203.0.113.50 (public IP)
Dest: 8.8.8.8
✅ Internet can route back to 203.0.113.50
```

**Rule:**
```json
{
  "name": "snat_internal",
  "sourceAddress": ["10.0.0.0/8"],
  "destinationAddress": ["any"],
  "sourceTranslation": {
    "type": "dynamic-ip-and-port",
    "translatedAddress": ["203.0.113.50"]
  }
}
```

---

### Destination NAT (DNAT) - Inbound

**Scenario:** External users need to access internal web server

```
BEFORE NAT:
┌─────────────┐                 ┌──────────┐
│ Internet    │                 │ Internal │
│ User        │────────────────→│ Web      │
└─────────────┘                 │ Server   │
Dest: 203.0.113.100             │10.100.10.│
❌ Can't reach 10.100.10.50      │   50     │
   (private IP, no routing)     └──────────┘

AFTER NAT (by firewall):
┌─────────────┐    ┌──────────┐    ┌──────────┐
│ Internet    │    │Firewall  │    │ Internal │
│ User        │───→│  DNAT    │───→│ Web      │
└─────────────┘    └──────────┘    │ Server   │
Dest: 203.0.113.100                │10.100.10.│
Firewall translates to:            │   50     │
  → 10.100.10.50                   └──────────┘
✅ Traffic reaches internal server
```

**Rule:**
```json
{
  "name": "dnat_web_server",
  "destinationAddress": ["203.0.113.100"],
  "service": ["tcp/80", "tcp/443"],
  "destinationTranslation": {
    "type": "static-ip",
    "translatedAddress": "10.100.10.50"
  }
}
```

---

## Zone-Based Architecture

### What are Zones?

```
┌───────────────────────────────────────────────┐
│              Firewall Zones                   │
│                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ UNTRUST  │  │   DMZ    │  │  TRUST   │   │
│  │          │  │          │  │          │   │
│  │ Internet │  │ Public   │  │ Internal │   │
│  │          │  │ Servers  │  │ Network  │   │
│  └──────────┘  └──────────┘  └──────────┘   │
│                                               │
└───────────────────────────────────────────────┘

Security Level:  LOW  ←────────────────→  HIGH
                (untrust)      (dmz)     (trust)
```

### Zone-to-Zone Traffic Rules

```
                     ALLOW / DENY?
            ┌──────────────────────────┐
            │                          │
         UNTRUST      DMZ        TRUST │
            │          │            │  │
UNTRUST  ─┼─→  ❌    →  ✅       →  ❌  │
            │  Block    Allow      Block│
            │  (no direct          (no  │
            │   access)            access)
            │                          │
DMZ      ─┼─→  ✅    →  ✅       →  ❌  │
            │  Allow    Allow      Block│
            │  (return  (DMZ peer) (no  │
            │   traffic)           backend)
            │                          │
TRUST    ─┼─→  ✅    →  ✅       →  ✅  │
            │  Allow    Allow      Allow│
            │  (internet) (access (internal)
            │             apps)         │
            └──────────────────────────┘

Legend:
✅ = Generally allowed (with security profiles)
❌ = Generally blocked (explicit allow needed)
```

### Example: DMZ Rule Set

```
Rule 1: UNTRUST → DMZ:443 (Allow)
  "Allow public to access web server"

Rule 2: DMZ → BACKEND:3306 (Allow)
  "Allow web server to query database"

Rule 3: DMZ → TRUST (Deny)
  "Block DMZ from accessing internal network"

Rule 4: TRUST → DMZ:443 (Allow)
  "Allow internal users to access DMZ apps"

Rule 5: TRUST → UNTRUST (Allow)
  "Allow internal users to access internet"
```

---

## Configuration Patterns

### Pattern 1: Internet Access

```
┌─────────────────────────────────────────────┐
│ Users → Internet (with protection)          │
├─────────────────────────────────────────────┤
│ Source: internal-users (10.0.0.0/8)         │
│ Destination: any                            │
│ Service: http, https                        │
│ Application: web-browsing, ssl              │
│ Action: allow                               │
│                                             │
│ Security Profiles:                          │
│  ✅ Antivirus                               │
│  ✅ Anti-Spyware                            │
│  ✅ Vulnerability Protection                │
│  ✅ URL Filtering (block: adult, malware)  │
│  ✅ WildFire                                │
└─────────────────────────────────────────────┘
```

### Pattern 2: VPN Access

```
┌─────────────────────────────────────────────┐
│ VPN Users → Corporate (secure)              │
├─────────────────────────────────────────────┤
│ Source: vpn-pool                            │
│ Destination: corporate-network              │
│ Service: any                                │
│ Action: allow                               │
│                                             │
│ User-ID: VPN username required              │
│ HIP Check: Endpoint compliance required     │
│ MFA: Duo Security required                  │
│                                             │
│ Security Profiles: Full stack               │
└─────────────────────────────────────────────┘
```

### Pattern 3: Block by Geolocation

```
┌─────────────────────────────────────────────┐
│ Block High-Risk Countries                   │
├─────────────────────────────────────────────┤
│ Source: any                                 │
│ Source Regions: CN, RU, KP, IR, SY         │
│ Destination: corporate-network              │
│ Service: any                                │
│ Action: drop                                │
│                                             │
│ Log: Security SIEM (threat intelligence)    │
│                                             │
│ Exception: Verified business partners       │
│  (separate allow rule above this one)       │
└─────────────────────────────────────────────┘
```

---

## Quick Decision Matrix

### Should I Add This Profile?

| Traffic Type | AV | AS | VUL | URL | FB | DLP | WF |
|--------------|----|----|-----|-----|----|----|-----|
| Web browsing | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| Email (SMTP) | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| File transfer (FTP) | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ | ✅ |
| Cloud storage | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ | ✅ |
| SSH | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Database (SQL) | ✅ | ✅ | ✅ | ❌ | ✅ | ⚠️ | ❌ |
| VPN | ✅ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | ✅ |
| DNS | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| ICMP (ping) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

Legend:
- ✅ = Recommended
- ⚠️ = Conditional (depends on sensitivity)
- ❌ = Not applicable

---

## Troubleshooting Flowchart

```
         Traffic Not Working?
                │
                ↓
         ┌──────────────┐
         │ Check logs:  │
         │ Traffic or   │
         │ Threat log?  │
         └──┬────────┬──┘
            │        │
        Traffic   Threat
            │        │
            ↓        ↓
    ┌──────────┐  ┌─────────┐
    │ Allowed  │  │ Blocked │
    │ or       │  │ by      │
    │ Denied?  │  │ profile?│
    └──┬───┬───┘  └────┬────┘
       │   │           │
     Allow Deny        │
       │   │           │
       ↓   ↓           ↓
    ┌────┐ ┌────┐  ┌────────┐
    │Fix │ │Add │  │Tune    │
    │App │ │Rule│  │Security│
    │    │ │    │  │Profile │
    └────┘ └────┘  └────────┘
```

---

For more details, see:
- [Complete Configuration Guide](CONFIGURATION-GUIDE.md)
- [Architecture Documentation](ARCHITECTURE.md)
- [Policy Validation Guide](POLICY-VALIDATION.md)
