# Configuration Guide - Complete Reference

> **For:** DevOps engineers, network administrators, security teams, and anyone learning firewall automation.
>
> **Goal:** Understand every configuration option in the Panorama mock API and how to use them.

---

## Table of Contents

1. [Configuration File Structure](#configuration-file-structure)
2. [Security Rules (policies.security)](#security-rules)
3. [NAT Policies (policies.nat)](#nat-policies)
4. [Decryption Policies (policies.decryption)](#decryption-policies)
5. [DoS Protection (policies.dos)](#dos-protection)
6. [Security Profiles](#security-profiles)
7. [Advanced Features](#advanced-features)
8. [Real-World Examples](#real-world-examples)
9. [Configuration Templates](#configuration-templates)
10. [Best Practices](#best-practices)

---

## Configuration File Structure

The `desired-config.json` file has this top-level structure:

```json
{
  "version": "1.0.0",
  "device": {
    "hostname": "panorama-mock",
    "model": "PA-5220"
  },
  "policies": {
    "security": [ ... ],      // Firewall rules
    "nat": [ ... ],           // NAT translations
    "decryption": [ ... ],    // SSL decryption
    "dos": [ ... ]            // DoS protection
  },
  "metadata": { ... },
  "globalSettings": { ... },
  "serviceDefinitions": { ... },
  "addressObjects": { ... },
  "securityProfiles": { ... }
}
```

---

## Security Rules

Security rules control **what traffic is allowed or blocked** through the firewall.

### Basic Security Rule Structure

```json
{
  "name": "rule-name",
  "source": ["10.0.0.0/8", "source-address-group"],
  "destination": ["any", "192.168.1.0/24"],
  "service": ["http", "https", "tcp/8080"],
  "application": ["web-browsing", "ssl"],
  "action": "allow",
  "enabled": true,
  "description": "Human-readable description"
}
```

### Complete Security Rule with All Options

```json
{
  "name": "complete-example-rule",
  "source": ["10.0.0.0/8", "corporate-users"],
  "destination": ["any"],
  "service": ["http", "https"],
  "application": ["web-browsing", "ssl"],
  "action": "allow",
  "enabled": true,
  "description": "Example rule showing all available options",
  
  "tags": {
    "category": "internet-access",
    "owner": "network-team",
    "compliance": "standard"
  },
  
  "log": {
    "atSessionStart": true,
    "atSessionEnd": true,
    "logForwarding": "syslog-server",
    "logType": "traffic"
  },
  
  "schedule": {
    "name": "business-hours",
    "type": "recurring",
    "days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "timeRange": "08:00-18:00"
  },
  
  "negate": {
    "source": false,
    "destination": false
  },
  
  "disabled": false,
  
  "hipProfiles": ["corporate-endpoint-security"],
  
  "sourceUser": ["domain\\it-team", "LDAP-group://admins"],
  "destinationUser": ["any"],
  
  "sourceRegions": ["US", "CA", "EU"],
  "destinationRegions": [],
  
  "qos": {
    "type": "ip-precedence",
    "value": 3,
    "class": 4
  },
  
  "rateLimit": {
    "enabled": true,
    "packetsPerSecond": 1000
  },
  
  "mfa": {
    "required": true,
    "profile": "duo-security"
  },
  
  "antivirus": "default-av-profile",
  "antiSpyware": "strict-anti-spyware",
  "vulnerability": "strict-vulnerability",
  "urlFiltering": {
    "profile": "strict-browsing",
    "override": false,
    "blockedCategories": ["adult", "gambling", "malware"]
  },
  "fileBlocking": "sensitive-data-profile",
  "dataFiltering": "pci-dss-data-filter",
  "wildfire": "wildfire-analysis",
  
  "securityProfiles": {
    "antivirus": "alternative-av",
    "antiSpyware": "alternative-as"
  }
}
```

---

## Field-by-Field Explanation

### 1. **name** (required)
- Unique identifier for the rule
- Used in logs and GUI
- Example: `"allow_web_browsing"`

### 2. **source** (required)
Source addresses - who is initiating the traffic

**Options:**
- `"any"` - Any source
- IP address: `"10.0.0.50"`
- CIDR: `"10.0.0.0/8"`, `"192.168.1.0/24"`
- Address group: `"internal-users"`, `"vpn-pool"`
- Multiple: `["10.0.0.0/8", "172.16.0.0/12"]`

**Examples:**
```json
"source": ["any"]
"source": ["10.0.0.0/8", "192.168.0.0/16"]
"source": ["corporate-users", "vpn-gateway"]
```

### 3. **destination** (required)
Destination addresses - where traffic is going

**Same options as source:**
```json
"destination": ["any"]
"destination": ["8.8.8.8", "8.8.4.4"]  // Google DNS
"destination": ["web-servers", "10.100.10.0/24"]
```

### 4. **service** (required)
Network services (ports/protocols)

**Common Services:**
- `"any"` - All services
- `"http"` - TCP port 80
- `"https"` - TCP port 443
- `"ssh"` - TCP port 22
- `"dns"` - TCP/UDP port 53
- `"smtp"` - TCP port 25
- Custom: `"tcp/8080"`, `"udp/5060"`

**Examples:**
```json
"service": ["http", "https"]
"service": ["tcp/8080", "tcp/8443"]
"service": ["any"]
```

### 5. **application** (optional but recommended)
Application identification (App-ID)

**Common Applications:**
- Web: `"web-browsing"`, `"ssl"`, `"http-proxy"`
- Business: `"office365-access"`, `"salesforce"`, `"slack"`
- Cloud: `"amazon-s3"`, `"ms-azure-storage"`, `"google-drive-base"`
- Communication: `"ms-teams"`, `"zoom"`, `"skype"`
- Remote: `"ssh"`, `"rdp"`, `"teamviewer"`

**Examples:**
```json
"application": ["web-browsing", "ssl"]
"application": ["office365-enterprise-access"]
"application": ["bittorrent", "torrent"]  // For blocking
```

### 6. **action** (required)
What to do with matching traffic

**Options:**
- `"allow"` - Permit the traffic
- `"deny"` - Block silently (no ICMP reject)
- `"drop"` - Block silently
- `"reset-client"` - Send TCP RST to client
- `"reset-server"` - Send TCP RST to server
- `"reset-both"` - Send TCP RST to both sides

**Examples:**
```json
"action": "allow"
"action": "deny"
```

### 7. **enabled** (required)
Whether the rule is active

```json
"enabled": true   // Rule is active
"enabled": false  // Rule is disabled (won't match traffic)
```

### 8. **description** (optional but recommended)
Human-readable explanation

```json
"description": "Allow internal users to browse the internet during business hours"
```

### 9. **tags** (optional)
Metadata for organization and filtering

```json
"tags": {
  "category": "internet-access",
  "owner": "network-team",
  "compliance": "pci-dss",
  "environment": "production",
  "cost-center": "IT-001"
}
```

### 10. **log** (optional)
Logging configuration

```json
"log": {
  "atSessionStart": true,        // Log when session starts
  "atSessionEnd": true,          // Log when session ends
  "logForwarding": "syslog-server",  // Where to send logs
  "logType": "traffic",          // Log type (traffic, threat, etc.)
  "logSetting": "detailed"       // Detail level
}
```

**When to log:**
- **Session start:** Authentication, high-value assets, compliance
- **Session end:** Most rules (shows bytes transferred, duration)
- **Both:** Security-critical rules

### 11. **schedule** (optional)
Time-based rules

```json
"schedule": {
  "name": "business-hours",
  "type": "recurring",
  "days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
  "timeRange": "08:00-18:00"
}
```

**Use cases:**
- Guest WiFi only during office hours
- Maintenance windows
- Restricted access times

### 12. **hipProfiles** (optional)
Host Information Profile - endpoint compliance

```json
"hipProfiles": ["corporate-endpoint-security", "antivirus-required"]
```

**Checks:**
- Antivirus installed and updated
- Firewall enabled
- Disk encryption
- OS patches applied

### 13. **sourceUser / destinationUser** (optional)
User-based rules (User-ID)

```json
"sourceUser": [
  "domain\\john.doe",
  "domain\\sales-team",
  "LDAP-group://developers"
],
"destinationUser": ["any"]
```

**Requires:**
- Active Directory / LDAP integration
- User-ID agent

### 14. **sourceRegions / destinationRegions** (optional)
Geolocation-based rules

```json
"sourceRegions": ["CN", "RU", "KP"],  // China, Russia, North Korea
"destinationRegions": []
```

**Country codes:** ISO 3166-1 alpha-2 (US, CA, GB, FR, CN, etc.)

### 15. **qos** (optional)
Quality of Service - traffic prioritization

```json
"qos": {
  "type": "ip-precedence",  // or "ip-dscp", "follow-c2s-flow"
  "value": 3,               // Priority (0-7 for precedence)
  "class": 4                // Traffic class
}
```

**Use cases:**
- VoIP traffic (high priority)
- Video conferencing
- Critical business apps
- Background backups (low priority)

### 16. **rateLimit** (optional)
Bandwidth throttling

```json
"rateLimit": {
  "enabled": true,
  "packetsPerSecond": 1000,
  "bytesPerSecond": 1000000  // 1 MB/s
}
```

### 17. **mfa** (optional)
Multi-factor authentication requirement

```json
"mfa": {
  "required": true,
  "profile": "duo-security"  // or "okta", "azure-mfa"
}
```

---

## Security Profiles

Security profiles provide **deep packet inspection** and **threat prevention**.

### Antivirus (AV)

Scans files for malware

```json
"antivirus": "default-av-profile"
```

**Profile examples:**
- `"default-av-profile"` - Standard scanning
- `"strict-av"` - Block all suspicious files
- `"email-av-profile"` - Optimized for email attachments
- `"cloud-av-profile"` - For cloud storage uploads

**What it does:**
- Scans HTTP downloads
- Email attachments
- File transfers (FTP, SMB)

### Anti-Spyware (AS)

Detects command-and-control traffic, botnets

```json
"antiSpyware": "strict-anti-spyware"
```

**Profile examples:**
- `"default-anti-spyware"` - Standard protection
- `"strict"` - Block all threats
- `"saas-anti-spyware"` - SaaS traffic optimized

**What it detects:**
- Botnet C&C traffic
- Spyware phone-home
- DNS tunneling
- Suspicious domains

### Vulnerability Protection

Protects against exploits (IPS)

```json
"vulnerability": "strict-vulnerability"
```

**Profile examples:**
- `"default-vulnerability"` - Standard protection
- `"strict-vulnerability"` - Block all exploits
- `"critical-high-medium"` - Block critical/high/medium severity

**What it blocks:**
- Buffer overflows
- SQL injection
- Code execution attempts
- Protocol anomalies

### URL Filtering

Blocks websites by category

```json
"urlFiltering": {
  "profile": "strict-browsing",
  "override": false,
  "blockedCategories": [
    "adult",
    "gambling",
    "malware",
    "phishing",
    "proxy-avoidance",
    "peer-to-peer",
    "hacking"
  ]
}
```

**Category examples:**
- Security: `"malware"`, `"phishing"`, `"command-and-control"`
- Productivity: `"social-networking"`, `"streaming-media"`, `"games"`
- Legal: `"adult"`, `"gambling"`, `"illegal-drugs"`
- Business: `"financial-services"`, `"health-and-medicine"`

### File Blocking

Blocks file types/extensions

```json
"fileBlocking": "strict-file-blocking"
```

**Typical blocks:**
- Executables: `.exe`, `.dll`, `.bat`, `.ps1`
- Scripts: `.vbs`, `.js`, `.jar`
- Archives: `.zip`, `.rar`, `.7z` (depending on policy)
- Office macros: `.docm`, `.xlsm`

### Data Filtering (DLP)

Prevents sensitive data leakage

```json
"dataFiltering": "pci-dss-data-filter"
```

**Profile examples:**
- `"pci-dss-data-filter"` - Credit card numbers
- `"phi-protection"` - Healthcare PHI (HIPAA)
- `"email-dlp-profile"` - SSN, financial data
- `"credit-card-protection"` - PAN detection

**What it detects:**
- Credit card numbers (PAN)
- Social Security Numbers
- Patient health records
- Source code patterns
- Custom regex patterns

### WildFire

Cloud-based sandboxing (malware analysis)

```json
"wildfire": "default"
```

**Profile examples:**
- `"default"` - Standard sandboxing
- `"wildfire-analysis"` - Deep analysis
- `"email-wildfire-analysis"` - Email attachments
- `"cloud-wildfire-analysis"` - Cloud uploads

**How it works:**
1. Unknown file encountered
2. Sent to WildFire cloud
3. Executed in sandbox VM
4. Verdict returned (malware/benign)
5. Signature distributed globally

---

## NAT Policies

NAT (Network Address Translation) modifies source/destination IPs.

### Source NAT (SNAT)

Translate internal IPs to public IP for internet access

```json
{
  "name": "snat_internal_to_internet",
  "description": "Source NAT for internal users",
  "sourceZone": ["trust"],
  "destinationZone": ["untrust"],
  "sourceAddress": ["10.0.0.0/8", "172.16.0.0/12"],
  "destinationAddress": ["any"],
  "service": ["any"],
  "sourceTranslation": {
    "type": "dynamic-ip-and-port",
    "translatedAddress": ["203.0.113.50", "203.0.113.51"],
    "interface": "ethernet1/1"
  },
  "enabled": true
}
```

**SNAT Types:**
- `"dynamic-ip-and-port"` - PAT (most common)
- `"dynamic-ip"` - One-to-one NAT pool
- `"static-ip"` - Fixed mapping

**Use case:** All internal users share 1-2 public IPs to access internet

### Destination NAT (DNAT)

Translate public IP to internal server (port forwarding)

```json
{
  "name": "dnat_public_web_to_dmz",
  "description": "Destination NAT for web server",
  "sourceZone": ["untrust"],
  "destinationZone": ["dmz"],
  "sourceAddress": ["any"],
  "destinationAddress": ["203.0.113.100"],  // Public IP
  "service": ["tcp/80", "tcp/443"],
  "destinationTranslation": {
    "type": "static-ip",
    "translatedAddress": "10.100.10.50",  // Internal web server
    "translatedPort": null  // Keep same port, or change it
  },
  "enabled": true
}
```

**Use case:** External users connect to your public IP, firewall forwards to internal server

### Port Translation

Change the destination port

```json
"destinationTranslation": {
  "type": "static-ip",
  "translatedAddress": "10.0.0.50",
  "translatedPort": 8080  // Public 80 → Internal 8080
}
```

---

## Decryption Policies

SSL/TLS decryption for inspecting encrypted traffic.

### Decrypt Outbound Traffic

```json
{
  "name": "decrypt_outbound_web",
  "description": "Decrypt HTTPS for malware/DLP inspection",
  "sourceZone": ["trust"],
  "destinationZone": ["untrust"],
  "sourceAddress": ["10.0.0.0/8"],
  "destinationAddress": ["any"],
  "service": ["https"],
  "action": "decrypt",
  "decryptionProfile": "standard-decryption",
  "enabled": true,
  "excludedCategories": [
    "financial-services",  // Don't decrypt banks
    "health-and-medicine"  // Don't decrypt healthcare (HIPAA)
  ]
}
```

**Actions:**
- `"decrypt"` - Decrypt and inspect
- `"no-decrypt"` - Bypass decryption

**Exclude categories:**
- Financial sites (banking)
- Healthcare (patient portals)
- Government sites

### No-Decrypt Rules

```json
{
  "name": "no_decrypt_trusted_domains",
  "description": "Bypass decryption for trusted corporate sites",
  "sourceZone": ["trust"],
  "destinationZone": ["untrust"],
  "sourceAddress": ["any"],
  "destinationAddress": [
    "*.company.com",
    "*.microsoft.com",
    "*.office365.com"
  ],
  "service": ["https"],
  "action": "no-decrypt",
  "enabled": true
}
```

**Privacy considerations:**
- Inform users about SSL inspection
- Exclude personal banking/health sites
- Install decryption certificate on endpoints

---

## DoS Protection

Protect against denial-of-service attacks.

```json
{
  "name": "rate_limit_public_web",
  "description": "DoS protection for public web servers",
  "zone": ["dmz"],
  "interface": ["ethernet1/2"],
  "ipAddress": ["10.100.10.0/24"],
  "protection": {
    "aggregate": {
      "enable": true,
      "alarm-rate": 10000,      // Connections/sec to alarm
      "activate-rate": 15000,   // Connections/sec to activate protection
      "maximal-rate": 20000     // Hard limit
    },
    "classified": {
      "enable": true,
      "alarm-rate": 1000,       // Per-source-IP alarm
      "activate-rate": 1500,    // Per-source-IP protection
      "maximal-rate": 2000      // Per-source-IP hard limit
    }
  },
  "enabled": true
}
```

**Protection types:**
- **Aggregate:** Total traffic to the server
- **Classified:** Per-source-IP limits

---

## Real-World Examples

### Example 1: Allow Internal Users to Browse Internet

```json
{
  "name": "allow_internal_web_browsing",
  "source": ["10.0.0.0/8", "172.16.0.0/12"],
  "destination": ["any"],
  "service": ["http", "https"],
  "application": ["web-browsing", "ssl"],
  "action": "allow",
  "enabled": true,
  "description": "Internal users can browse web",
  "antivirus": "default-av-profile",
  "antiSpyware": "default-anti-spyware",
  "vulnerability": "default-vulnerability",
  "urlFiltering": {
    "profile": "corporate-browsing",
    "blockedCategories": ["adult", "gambling", "malware"]
  },
  "wildfire": "default"
}
```

### Example 2: Block External SSH Access

```json
{
  "name": "block_external_ssh",
  "source": ["any"],
  "destination": ["10.0.0.0/8", "172.16.0.0/12"],
  "service": ["ssh", "tcp/2222"],
  "action": "drop",
  "enabled": true,
  "description": "Block external SSH to prevent brute force",
  "log": {
    "atSessionStart": true,
    "atSessionEnd": true,
    "logForwarding": "security-siem"
  }
}
```

### Example 3: VPN Users with Endpoint Compliance

```json
{
  "name": "allow_vpn_users",
  "source": ["vpn-pool"],
  "destination": ["corporate-network"],
  "service": ["any"],
  "action": "allow",
  "enabled": true,
  "description": "VPN access with endpoint checks",
  "hipProfiles": ["corporate-endpoint-security"],
  "mfa": {
    "required": true,
    "profile": "duo-security"
  },
  "antivirus": "strict-av",
  "antiSpyware": "strict"
}
```

### Example 4: Guest WiFi with Time Restrictions

```json
{
  "name": "guest_wifi_business_hours",
  "source": ["guest-wifi-zone", "192.168.99.0/24"],
  "destination": ["any"],
  "service": ["http", "https"],
  "action": "allow",
  "enabled": true,
  "description": "Guest WiFi, 8am-6pm weekdays only",
  "schedule": {
    "name": "business-hours",
    "type": "recurring",
    "days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "timeRange": "08:00-18:00"
  },
  "urlFiltering": {
    "profile": "guest-safe-browsing",
    "blockedCategories": ["adult", "gambling", "malware", "peer-to-peer"]
  }
}
```

### Example 5: Cloud Storage Access (AWS S3)

```json
{
  "name": "allow_aws_s3",
  "source": ["app-servers"],
  "destination": ["aws-s3-prefix-list"],
  "service": ["application-default"],
  "application": ["amazon-s3"],
  "action": "allow",
  "enabled": true,
  "description": "Application servers to AWS S3",
  "antivirus": "cloud-av-profile",
  "fileBlocking": "cloud-file-blocking",
  "wildfire": "cloud-wildfire-analysis"
}
```

### Example 6: Block High-Risk Countries

```json
{
  "name": "block_high_risk_geoip",
  "source": ["high-risk-geoip"],
  "destination": ["corporate-network"],
  "service": ["any"],
  "action": "drop",
  "enabled": true,
  "description": "Block traffic from CN, RU, KP, IR, SY",
  "sourceRegions": ["CN", "RU", "KP", "IR", "SY"],
  "log": {
    "atSessionStart": true,
    "atSessionEnd": true,
    "logForwarding": "threat-intelligence"
  }
}
```

### Example 7: Developer SSH Access (User-ID)

```json
{
  "name": "allow_dev_ssh",
  "source": ["dev-team-users"],
  "destination": ["dev-servers"],
  "service": ["ssh"],
  "action": "allow",
  "enabled": true,
  "description": "Developers can SSH to dev environment",
  "sourceUser": [
    "domain\\dev-team",
    "LDAP-group://developers"
  ],
  "hipProfiles": ["dev-workstation-compliance"],
  "mfa": {
    "required": true,
    "profile": "duo-security"
  },
  "log": {
    "atSessionStart": true,
    "atSessionEnd": true,
    "logForwarding": "audit-logs"
  }
}
```

### Example 8: PCI-DSS Compliance Rule

```json
{
  "name": "pci_dss_cardholder_access",
  "source": ["any"],
  "destination": ["pci-dss-servers"],
  "service": ["any"],
  "action": "allow",
  "enabled": true,
  "description": "PCI-DSS cardholder data environment",
  "tags": {
    "compliance": "pci-dss",
    "scope": "cardholder-data-environment"
  },
  "log": {
    "atSessionStart": true,
    "atSessionEnd": true,
    "logForwarding": "siem-compliance-pci",
    "logSetting": "detailed"
  },
  "antivirus": "strict-av",
  "antiSpyware": "strict",
  "vulnerability": "critical-high-medium",
  "fileBlocking": "strict-file-blocking",
  "dataFiltering": "credit-card-protection"
}
```

---

## Configuration Templates

### Template: Basic Allow Rule

```json
{
  "name": "CHANGE_ME",
  "source": ["SOURCE_IPS"],
  "destination": ["DEST_IPS"],
  "service": ["SERVICE"],
  "action": "allow",
  "enabled": true,
  "description": "DESCRIBE_THE_RULE"
}
```

### Template: Security-Hardened Rule

```json
{
  "name": "CHANGE_ME",
  "source": ["SOURCE"],
  "destination": ["DEST"],
  "service": ["SERVICE"],
  "action": "allow",
  "enabled": true,
  "description": "DESCRIBE",
  "log": {
    "atSessionStart": false,
    "atSessionEnd": true,
    "logForwarding": "syslog-server"
  },
  "antivirus": "default-av-profile",
  "antiSpyware": "default-anti-spyware",
  "vulnerability": "default-vulnerability",
  "fileBlocking": "default-file-blocking",
  "wildfire": "default"
}
```

### Template: Block Rule

```json
{
  "name": "block_CHANGE_ME",
  "source": ["any"],
  "destination": ["PROTECTED_NETWORK"],
  "service": ["BLOCKED_SERVICE"],
  "action": "drop",
  "enabled": true,
  "description": "Block DESCRIBE_WHAT",
  "log": {
    "atSessionStart": true,
    "atSessionEnd": true,
    "logForwarding": "security-siem"
  }
}
```

---

## Best Practices

### 1. **Rule Ordering Matters**

Rules are evaluated **top-to-bottom**. First match wins.

**Good order:**
1. Explicit denies (block known bad)
2. Specific allows (narrowly scoped)
3. General allows (broader scope)
4. Default deny (implicit at bottom)

### 2. **Use Descriptive Names**

❌ Bad: `rule1`, `policy_new`, `temp`
✅ Good: `allow_vpn_users`, `block_external_ssh`, `deny_p2p_protocols`

### 3. **Always Add Descriptions**

```json
"description": "Allow sales team to access CRM during business hours"
```

### 4. **Enable Logging Appropriately**

- **Session end:** Most rules
- **Session start + end:** Security-critical, compliance
- **No logging:** High-volume internal traffic (ICMP, DNS)

### 5. **Use Security Profiles on Allow Rules**

Every `"allow"` rule should have at minimum:
- Antivirus
- Anti-Spyware
- Vulnerability Protection
- WildFire

### 6. **Tag Everything**

```json
"tags": {
  "owner": "network-team",
  "category": "internet-access",
  "compliance": "standard",
  "cost-center": "IT-001"
}
```

### 7. **Be Specific with Sources/Destinations**

❌ Bad: `"source": ["any"], "destination": ["any"]`
✅ Good: `"source": ["10.0.0.0/8"], "destination": ["web-servers"]`

### 8. **Use Application-Based Rules**

Prefer App-ID over port-based rules:

❌ Port-based:
```json
"service": ["tcp/443"]
```

✅ Application-based:
```json
"service": ["application-default"],
"application": ["ssl", "web-browsing"]
```

### 9. **Document Compliance Requirements**

```json
"tags": {
  "compliance": "pci-dss",
  "requirement": "1.2.1",
  "audit-required": "true"
}
```

### 10. **Test in Disabled State First**

```json
"enabled": false,
"description": "TESTING - Enable after verification"
```

---

## Common Mistakes to Avoid

### ❌ Mistake 1: No Security Profiles

```json
{
  "name": "allow_web",
  "action": "allow",
  // Missing: antivirus, antiSpyware, etc.
}
```

**Impact:** No malware/exploit protection

### ❌ Mistake 2: Overly Broad Rules

```json
{
  "name": "allow_everything",
  "source": ["any"],
  "destination": ["any"],
  "service": ["any"],
  "action": "allow"
}
```

**Impact:** Defeats the purpose of a firewall

### ❌ Mistake 3: No Logging

```json
{
  "name": "important_rule",
  "action": "allow"
  // Missing: log configuration
}
```

**Impact:** No forensics, compliance issues

### ❌ Mistake 4: Decrypt Everything

```json
{
  "name": "decrypt_all_https",
  "destinationAddress": ["any"],  // Including banks!
  "action": "decrypt"
}
```

**Impact:** Privacy violations, broken sites

### ❌ Mistake 5: Ignoring User-ID

```json
{
  "name": "allow_admin_access",
  "source": ["10.0.0.50"]  // IP can change!
}
```

**Better:**
```json
{
  "name": "allow_admin_access",
  "sourceUser": ["domain\\admins"]
}
```

---

## Troubleshooting Configuration Issues

### Issue: Rule Not Matching

**Check:**
1. Rule order (is a deny rule above it?)
2. Source/destination addresses
3. Service/application mismatch
4. Rule disabled (`"enabled": false`)
5. Schedule restrictions

### Issue: Security Profile Not Applied

**Check:**
1. Action is `"allow"` (profiles only on allow rules)
2. Profile name exists
3. JSON syntax (commas, quotes)

### Issue: Logging Not Working

**Check:**
1. `"log"` section present
2. Log forwarding profile exists
3. `"atSessionEnd": true` (most common)

---

## Quick Reference

### Minimal Working Rule

```json
{
  "name": "test-rule",
  "source": ["10.0.0.0/8"],
  "destination": ["any"],
  "service": ["http"],
  "action": "allow",
  "enabled": true
}
```

### Production-Ready Rule

```json
{
  "name": "production-rule",
  "source": ["10.0.0.0/8"],
  "destination": ["any"],
  "service": ["http", "https"],
  "application": ["web-browsing", "ssl"],
  "action": "allow",
  "enabled": true,
  "description": "Detailed description here",
  "log": {
    "atSessionEnd": true,
    "logForwarding": "syslog-server"
  },
  "antivirus": "default-av-profile",
  "antiSpyware": "default-anti-spyware",
  "vulnerability": "default-vulnerability",
  "wildfire": "default"
}
```

---

## Next Steps

1. **Start Simple:** Copy the minimal rule template and test
2. **Add Security:** Add security profiles one at a time
3. **Enable Logging:** See what traffic is matching
4. **Refine:** Narrow sources/destinations, add schedules
5. **Document:** Add descriptions and tags

**Happy configuring!** 🔥

For more help:
- [Architecture Guide](ARCHITECTURE.md)
- [Drift Detection Guide](DRIFT-DETECTION.md)
- [Policy Validation Guide](POLICY-VALIDATION.md)
