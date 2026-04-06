# Firewall Security Policy - Advanced Validation with OPA
# This policy enforces enterprise-grade security rules for Palo Alto firewall configurations

package firewall.security

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ==============================================================================
# DENY RULES - Security violations that must be blocked
# ==============================================================================

# Deny: Blanket allow-all rules (any → any)
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Check if source contains "any"
    "any" in rule.source
    
    # Check if destination contains "any"
    "any" in rule.destination
    
    # Check if service contains "any"
    "any" in rule.service
    
    # Exception: Emergency rules that are disabled
    not rule.name == "emergency_disable_rule"
    
    msg := sprintf("Rule '%s' is a blanket allow-all (any→any→any) which violates security policy", [rule.name])
}

# Deny: Rules without description
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    not rule.description
    
    msg := sprintf("Rule '%s' is missing a description", [rule.name])
}

# Deny: Allow rules without security profiles (critical)
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Must have at least AV + AS + VUL
    not has_critical_security_profiles(rule)
    
    # Exceptions for non-file-transfer protocols
    not is_protocol_exception(rule)
    
    msg := sprintf("Rule '%s' allows traffic without critical security profiles (AV, AS, VUL required)", [rule.name])
}

# Helper: Check if rule has critical security profiles
has_critical_security_profiles(rule) {
    # Check direct fields
    rule.antivirus
    rule.antiSpyware
    rule.vulnerability
}

has_critical_security_profiles(rule) {
    # Or check securityProfiles object
    rule.securityProfiles.antivirus
    rule.securityProfiles.antiSpyware
    rule.securityProfiles.vulnerability
}

# Helper: Protocol exceptions (ICMP, DNS don't need AV)
is_protocol_exception(rule) {
    "icmp" in rule.service
}

is_protocol_exception(rule) {
    "ping" in rule.service
}

is_protocol_exception(rule) {
    rule.name == "force_dns_to_port_53"
}

is_protocol_exception(rule) {
    rule.name == "emergency_disable_rule"
    rule.enabled == false
}

is_protocol_exception(rule) {
    rule.name == "test_drift_rule"
}

# Deny: Outbound traffic without logging
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Outbound to internet
    "any" in rule.destination
    
    # No logging configured
    not rule.log.atSessionEnd
    
    # Not an exception (ICMP, internal-only)
    not is_logging_exception(rule)
    
    msg := sprintf("Rule '%s' allows outbound traffic without session-end logging", [rule.name])
}

is_logging_exception(rule) {
    "icmp" in rule.service
}

is_logging_exception(rule) {
    "ping" in rule.service
}

# Deny: External SSH access allowed
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Source is external (any or untrust)
    "any" in rule.source
    
    # Destination is internal network
    some dest in rule.destination
    is_private_network(dest)
    
    # Service is SSH
    "ssh" in rule.service
    
    msg := sprintf("Rule '%s' allows external SSH access to internal networks (security risk)", [rule.name])
}

# Helper: Check if IP is private network
is_private_network(ip) {
    startswith(ip, "10.")
}

is_private_network(ip) {
    startswith(ip, "172.16.")
}

is_private_network(ip) {
    startswith(ip, "192.168.")
}

# Deny: P2P/Torrent applications allowed
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Check if application list contains P2P
    some app in rule.application
    is_p2p_application(app)
    
    msg := sprintf("Rule '%s' allows P2P/Torrent applications (bandwidth + legal risk)", [rule.name])
}

is_p2p_application(app) {
    app == "bittorrent"
}

is_p2p_application(app) {
    app == "torrent"
}

is_p2p_application(app) {
    app == "utorrent"
}

is_p2p_application(app) {
    app == "emule"
}

# Deny: Risky remote access tools allowed
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    some app in rule.application
    is_risky_remote_tool(app)
    
    msg := sprintf("Rule '%s' allows risky remote access tool '%s' (security risk)", [rule.name, app])
}

is_risky_remote_tool(app) {
    app == "teamviewer"
}

is_risky_remote_tool(app) {
    app == "anydesk"
}

is_risky_remote_tool(app) {
    app == "logmein"
}

is_risky_remote_tool(app) {
    app == "tor"
}

# ==============================================================================
# WARN RULES - Best practices violations (not blocking)
# ==============================================================================

# Warn: Rules without tags
warn[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    not rule.tags
    
    msg := sprintf("Rule '%s' has no tags (recommended: category, owner, compliance)", [rule.name])
}

# Warn: Web traffic without URL filtering
warn[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Web-related applications
    some app in rule.application
    is_web_application(app)
    
    # No URL filtering
    not rule.urlFiltering
    not rule.securityProfiles.urlFiltering
    
    msg := sprintf("Rule '%s' allows web traffic without URL filtering (recommended)", [rule.name])
}

is_web_application(app) {
    app == "web-browsing"
}

is_web_application(app) {
    app == "ssl"
}

is_web_application(app) {
    app == "http"
}

is_web_application(app) {
    app == "https"
}

# Warn: File transfer without WildFire
warn[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # File transfer protocols
    some app in rule.application
    is_file_transfer_app(app)
    
    # No WildFire
    not rule.wildfire
    not rule.securityProfiles.wildfire
    
    msg := sprintf("Rule '%s' allows file transfer without WildFire sandboxing (recommended)", [rule.name])
}

is_file_transfer_app(app) {
    app == "ftp"
}

is_file_transfer_app(app) {
    app == "sftp"
}

is_file_transfer_app(app) {
    contains(app, "cloud")
}

is_file_transfer_app(app) {
    contains(app, "s3")
}

is_file_transfer_app(app) {
    contains(app, "storage")
}

# Warn: DMZ traffic without strict profiles
warn[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # DMZ-related traffic
    some dest in rule.destination
    contains(dest, "dmz")
    
    # Not using strict profiles
    not is_strict_profile(rule)
    
    msg := sprintf("Rule '%s' allows DMZ traffic without strict security profiles (recommended)", [rule.name])
}

is_strict_profile(rule) {
    contains(rule.antivirus, "strict")
}

is_strict_profile(rule) {
    contains(rule.securityProfiles.antivirus, "strict")
}

# Warn: VPN access without HIP check
warn[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # VPN-related
    some src in rule.source
    contains(src, "vpn")
    
    # No HIP profiles
    count(rule.hipProfiles) == 0
    
    msg := sprintf("Rule '%s' allows VPN access without HIP (endpoint compliance) checks (recommended)", [rule.name])
}

# Warn: Admin/Dev access without MFA
warn[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # SSH or RDP
    some svc in rule.service
    is_admin_service(svc)
    
    # No MFA required
    not rule.mfa.required
    
    # Not test/emergency rule
    not contains(rule.name, "test")
    not contains(rule.name, "emergency")
    
    msg := sprintf("Rule '%s' allows admin access without MFA (strongly recommended)", [rule.name])
}

is_admin_service(svc) {
    svc == "ssh"
}

is_admin_service(svc) {
    svc == "rdp"
}

is_admin_service(svc) {
    svc == "tcp/22"
}

is_admin_service(svc) {
    svc == "tcp/3389"
}

# ==============================================================================
# COMPLIANCE RULES - Regulatory requirements
# ==============================================================================

# Compliance: PCI-DSS rules must have enhanced logging
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Tagged as PCI-DSS
    rule.tags.compliance == "pci-dss"
    
    # Must log session start AND end
    not rule.log.atSessionStart
    
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing session-start logging (required)", [rule.name])
}

# Compliance: PCI-DSS rules must have data filtering
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    rule.tags.compliance == "pci-dss"
    
    # Must have DLP for credit card protection
    not rule.dataFiltering
    not rule.securityProfiles.dataFiltering
    
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing data filtering/DLP (required)", [rule.name])
}

# Compliance: HIPAA rules must have PHI protection
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    rule.tags.standard == "hipaa"
    
    # Must have PHI data filtering
    not contains(rule.dataFiltering, "phi")
    not contains(rule.securityProfiles.dataFiltering, "phi")
    
    msg := sprintf("Rule '%s' is HIPAA scoped but missing PHI data filtering (required)", [rule.name])
}

# ==============================================================================
# NAT POLICY VALIDATION
# ==============================================================================

# Deny: SNAT without proper source address
deny[msg] {
    some nat in input.policies.nat
    nat.enabled == true
    
    # SNAT rule
    nat.sourceTranslation.type == "dynamic-ip-and-port"
    
    # Source is "any" (too broad)
    "any" in nat.sourceAddress
    
    msg := sprintf("NAT rule '%s' uses 'any' as source (should be specific internal networks)", [nat.name])
}

# Warn: DNAT without security rule
warn[msg] {
    some nat in input.policies.nat
    nat.enabled == true
    
    # DNAT rule
    nat.destinationTranslation
    
    # Check if there's a matching security rule
    not has_matching_security_rule(nat)
    
    msg := sprintf("NAT rule '%s' has no corresponding security rule (traffic will be blocked)", [nat.name])
}

has_matching_security_rule(nat) {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    # Simplified check: just verify a rule exists for the zone
    nat.destinationZone
}

# ==============================================================================
# DECRYPTION POLICY VALIDATION
# ==============================================================================

# Warn: Decrypting financial/healthcare sites
warn[msg] {
    some decrypt in input.policies.decryption
    decrypt.action == "decrypt"
    decrypt.enabled == true
    
    # Doesn't exclude sensitive categories
    not contains(decrypt.excludedCategories[_], "financial-services")
    
    msg := sprintf("Decryption rule '%s' may decrypt financial sites (privacy concern)", [decrypt.name])
}

warn[msg] {
    some decrypt in input.policies.decryption
    decrypt.action == "decrypt"
    decrypt.enabled == true
    
    not contains(decrypt.excludedCategories[_], "health-and-medicine")
    
    msg := sprintf("Decryption rule '%s' may decrypt healthcare sites (HIPAA concern)", [decrypt.name])
}

# ==============================================================================
# STATISTICS & REPORTING
# ==============================================================================

# Count total rules
rule_count := count(input.policies.security)

# Count allow rules
allow_rule_count := count([rule | rule := input.policies.security[_]; rule.action == "allow"])

# Count deny rules
deny_rule_count := count([rule | rule := input.policies.security[_]; rule.action == "deny"]) +
                   count([rule | rule := input.policies.security[_]; rule.action == "drop"])

# Count rules with security profiles
rules_with_profiles := count([rule |
    rule := input.policies.security[_]
    rule.action == "allow"
    has_critical_security_profiles(rule)
])

# Calculate security profile coverage percentage
security_profile_coverage := (rules_with_profiles * 100) / allow_rule_count

# Summary report
summary := {
    "total_rules": rule_count,
    "allow_rules": allow_rule_count,
    "deny_rules": deny_rule_count,
    "rules_with_security_profiles": rules_with_profiles,
    "security_profile_coverage_percent": security_profile_coverage,
    "violations": count(deny),
    "warnings": count(warn)
}
