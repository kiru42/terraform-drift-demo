# Firewall Security Policy - Advanced Validation with OPA
# Compatible with OPA 0.20+ (legacy syntax)

package firewall.security

# ==============================================================================
# DENY RULES - Security violations
# ==============================================================================

# Deny: Blanket allow-all rules
deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    rule.source[_] = "any"
    rule.destination[_] = "any"
    rule.service[_] = "any"
    not rule.name = "emergency_disable_rule"
    msg := sprintf("Rule '%s' is a blanket allow-all (any→any→any)", [rule.name])
}

# Deny: Missing description
deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    not rule.description
    msg := sprintf("Rule '%s' is missing a description", [rule.name])
}

# Deny: No security profiles
deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    not has_critical_security_profiles(rule)
    not is_protocol_exception(rule)
    msg := sprintf("Rule '%s' allows traffic without critical security profiles (AV, AS, VUL required)", [rule.name])
}

# Helper: Check security profiles
has_critical_security_profiles(rule) = true {
    rule.antivirus
    rule.antiSpyware
    rule.vulnerability
}

has_critical_security_profiles(rule) = true {
    rule.securityProfiles.antivirus
    rule.securityProfiles.antiSpyware
    rule.securityProfiles.vulnerability
}

# Helper: Protocol exceptions
is_protocol_exception(rule) = true {
    rule.service[_] = "icmp"
}

is_protocol_exception(rule) = true {
    rule.service[_] = "ping"
}

is_protocol_exception(rule) = true {
    rule.name = "force_dns_to_port_53"
}

is_protocol_exception(rule) = true {
    rule.name = "emergency_disable_rule"
}

is_protocol_exception(rule) = true {
    rule.name = "test_drift_rule"
}

# Deny: No logging on outbound
deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    rule.destination[_] = "any"
    not rule.log.atSessionEnd
    not is_logging_exception(rule)
    msg := sprintf("Rule '%s' allows outbound traffic without session-end logging", [rule.name])
}

is_logging_exception(rule) = true {
    rule.service[_] = "icmp"
}

is_logging_exception(rule) = true {
    rule.service[_] = "ping"
}

# Deny: External SSH to internal
deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    rule.source[_] = "any"
    dest := rule.destination[_]
    is_private_network(dest)
    rule.service[_] = "ssh"
    msg := sprintf("Rule '%s' allows external SSH access to internal networks (security risk)", [rule.name])
}

is_private_network(ip) = true {
    startswith(ip, "10.")
}

is_private_network(ip) = true {
    startswith(ip, "172.16.")
}

is_private_network(ip) = true {
    startswith(ip, "192.168.")
}

# Deny: P2P applications
deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    app := rule.application[_]
    is_p2p_application(app)
    msg := sprintf("Rule '%s' allows P2P/Torrent applications (bandwidth + legal risk)", [rule.name])
}

is_p2p_application(app) = true {
    app = "bittorrent"
}

is_p2p_application(app) = true {
    app = "torrent"
}

is_p2p_application(app) = true {
    app = "utorrent"
}

is_p2p_application(app) = true {
    app = "emule"
}

# Deny: Risky remote tools
deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    app := rule.application[_]
    is_risky_remote_tool(app)
    msg := sprintf("Rule '%s' allows risky remote access tool '%s'", [rule.name, app])
}

is_risky_remote_tool(app) = true {
    app = "teamviewer"
}

is_risky_remote_tool(app) = true {
    app = "anydesk"
}

is_risky_remote_tool(app) = true {
    app = "logmein"
}

is_risky_remote_tool(app) = true {
    app = "tor"
}

# ==============================================================================
# WARN RULES - Best practices
# ==============================================================================

warn[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    not rule.tags
    msg := sprintf("Rule '%s' has no tags (recommended)", [rule.name])
}

warn[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    app := rule.application[_]
    is_web_application(app)
    not rule.urlFiltering
    not rule.securityProfiles.urlFiltering
    msg := sprintf("Rule '%s' allows web traffic without URL filtering (recommended)", [rule.name])
}

is_web_application(app) = true {
    app = "web-browsing"
}

is_web_application(app) = true {
    app = "ssl"
}

is_web_application(app) = true {
    app = "http"
}

is_web_application(app) = true {
    app = "https"
}

warn[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    app := rule.application[_]
    is_file_transfer_app(app)
    not rule.wildfire
    not rule.securityProfiles.wildfire
    msg := sprintf("Rule '%s' allows file transfer without WildFire (recommended)", [rule.name])
}

is_file_transfer_app(app) = true {
    app = "ftp"
}

is_file_transfer_app(app) = true {
    app = "sftp"
}

is_file_transfer_app(app) = true {
    contains(app, "cloud")
}

is_file_transfer_app(app) = true {
    contains(app, "s3")
}

is_file_transfer_app(app) = true {
    contains(app, "storage")
}

warn[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    src := rule.source[_]
    contains(src, "vpn")
    count(rule.hipProfiles) = 0
    msg := sprintf("Rule '%s' allows VPN access without HIP checks (recommended)", [rule.name])
}

warn[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    svc := rule.service[_]
    is_admin_service(svc)
    not rule.mfa.required
    not contains(rule.name, "test")
    not contains(rule.name, "emergency")
    msg := sprintf("Rule '%s' allows admin access without MFA (recommended)", [rule.name])
}

is_admin_service(svc) = true {
    svc = "ssh"
}

is_admin_service(svc) = true {
    svc = "rdp"
}

is_admin_service(svc) = true {
    svc = "tcp/22"
}

is_admin_service(svc) = true {
    svc = "tcp/3389"
}

# ==============================================================================
# COMPLIANCE
# ==============================================================================

deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    rule.tags.compliance = "pci-dss"
    not rule.log.atSessionStart
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing session-start logging (required)", [rule.name])
}

deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    rule.tags.compliance = "pci-dss"
    not rule.dataFiltering
    not rule.securityProfiles.dataFiltering
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing data filtering/DLP (required)", [rule.name])
}

deny[msg] {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    rule.tags.standard = "hipaa"
    not contains(rule.dataFiltering, "phi")
    not contains(rule.securityProfiles.dataFiltering, "phi")
    msg := sprintf("Rule '%s' is HIPAA scoped but missing PHI data filtering (required)", [rule.name])
}

# ==============================================================================
# NAT VALIDATION
# ==============================================================================

deny[msg] {
    nat := input.policies.nat[_]
    nat.enabled = true
    nat.sourceTranslation.type = "dynamic-ip-and-port"
    nat.sourceAddress[_] = "any"
    msg := sprintf("NAT rule '%s' uses 'any' as source (should be specific)", [nat.name])
}

warn[msg] {
    nat := input.policies.nat[_]
    nat.enabled = true
    nat.destinationTranslation
    not has_matching_security_rule(nat)
    msg := sprintf("NAT rule '%s' has no corresponding security rule (traffic will be blocked)", [nat.name])
}

has_matching_security_rule(nat) = true {
    rule := input.policies.security[_]
    rule.action = "allow"
    rule.enabled = true
    nat.destinationZone
}

# ==============================================================================
# DECRYPTION VALIDATION
# ==============================================================================

warn[msg] {
    decrypt := input.policies.decryption[_]
    decrypt.action = "decrypt"
    decrypt.enabled = true
    not decrypt.excludedCategories[_] = "financial-services"
    msg := sprintf("Decryption rule '%s' may decrypt financial sites (privacy concern)", [decrypt.name])
}

warn[msg] {
    decrypt := input.policies.decryption[_]
    decrypt.action = "decrypt"
    decrypt.enabled = true
    not decrypt.excludedCategories[_] = "health-and-medicine"
    msg := sprintf("Decryption rule '%s' may decrypt healthcare sites (HIPAA concern)", [decrypt.name])
}

# ==============================================================================
# STATISTICS
# ==============================================================================

rule_count = count(input.policies.security)

allow_rule_count = count([rule | rule := input.policies.security[_]; rule.action = "allow"])

deny_rule_count = count([rule | rule := input.policies.security[_]; rule.action = "deny"]) +
                   count([rule | rule := input.policies.security[_]; rule.action = "drop"])

rules_with_profiles = count([rule |
    rule := input.policies.security[_]
    rule.action = "allow"
    has_critical_security_profiles(rule)
])

security_profile_coverage = (rules_with_profiles * 100) / allow_rule_count

summary = {
    "total_rules": rule_count,
    "allow_rules": allow_rule_count,
    "deny_rules": deny_rule_count,
    "rules_with_security_profiles": rules_with_profiles,
    "security_profile_coverage_percent": security_profile_coverage,
    "violations": count(deny),
    "warnings": count(warn)
}
