# Firewall Security Policy - OPA 1.0+ compatible
package firewall.security

import rego.v1

# ==============================================================================
# DENY RULES
# ==============================================================================

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    rule.source[_] == "any"
    rule.destination[_] == "any"
    rule.service[_] == "any"
    not rule.name == "emergency_disable_rule"
    msg := sprintf("Rule '%s' is a blanket allow-all (any→any→any)", [rule.name])
}

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    not rule.description
    msg := sprintf("Rule '%s' is missing a description", [rule.name])
}

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    not has_critical_security_profiles(rule)
    not is_protocol_exception(rule)
    msg := sprintf("Rule '%s' allows traffic without critical security profiles", [rule.name])
}

has_critical_security_profiles(rule) if {
    rule.antivirus
    rule.antiSpyware
    rule.vulnerability
}

has_critical_security_profiles(rule) if {
    rule.securityProfiles.antivirus
    rule.securityProfiles.antiSpyware
    rule.securityProfiles.vulnerability
}

is_protocol_exception(rule) if {
    rule.service[_] == "icmp"
}

is_protocol_exception(rule) if {
    rule.service[_] == "ping"
}

is_protocol_exception(rule) if {
    rule.name == "force_dns_to_port_53"
}

is_protocol_exception(rule) if {
    rule.name == "emergency_disable_rule"
}

is_protocol_exception(rule) if {
    rule.name == "test_drift_rule"
}

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    rule.destination[_] == "any"
    not rule.log.atSessionEnd
    not is_logging_exception(rule)
    msg := sprintf("Rule '%s' allows outbound traffic without session-end logging", [rule.name])
}

is_logging_exception(rule) if {
    rule.service[_] == "icmp"
}

is_logging_exception(rule) if {
    rule.service[_] == "ping"
}

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    rule.source[_] == "any"
    dest := rule.destination[_]
    is_private_network(dest)
    rule.service[_] == "ssh"
    msg := sprintf("Rule '%s' allows external SSH access to internal networks", [rule.name])
}

is_private_network(ip) if {
    startswith(ip, "10.")
}

is_private_network(ip) if {
    startswith(ip, "172.16.")
}

is_private_network(ip) if {
    startswith(ip, "192.168.")
}

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    app := rule.application[_]
    is_p2p_application(app)
    msg := sprintf("Rule '%s' allows P2P/Torrent applications", [rule.name])
}

is_p2p_application(app) if {
    app == "bittorrent"
}

is_p2p_application(app) if {
    app == "torrent"
}

is_p2p_application(app) if {
    app == "utorrent"
}

is_p2p_application(app) if {
    app == "emule"
}

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    app := rule.application[_]
    is_risky_remote_tool(app)
    msg := sprintf("Rule '%s' allows risky remote access tool '%s'", [rule.name, app])
}

is_risky_remote_tool(app) if {
    app == "teamviewer"
}

is_risky_remote_tool(app) if {
    app == "anydesk"
}

is_risky_remote_tool(app) if {
    app == "logmein"
}

is_risky_remote_tool(app) if {
    app == "tor"
}

# ==============================================================================
# WARN RULES
# ==============================================================================

warn contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    not rule.tags
    msg := sprintf("Rule '%s' has no tags (recommended)", [rule.name])
}

warn contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    app := rule.application[_]
    is_web_application(app)
    not rule.urlFiltering
    not rule.securityProfiles.urlFiltering
    msg := sprintf("Rule '%s' allows web traffic without URL filtering", [rule.name])
}

is_web_application(app) if {
    app == "web-browsing"
}

is_web_application(app) if {
    app == "ssl"
}

warn contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    app := rule.application[_]
    is_file_transfer_app(app)
    not rule.wildfire
    not rule.securityProfiles.wildfire
    msg := sprintf("Rule '%s' allows file transfer without WildFire", [rule.name])
}

is_file_transfer_app(app) if {
    contains(app, "s3")
}

is_file_transfer_app(app) if {
    contains(app, "storage")
}

warn contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    src := rule.source[_]
    contains(src, "vpn")
    count(rule.hipProfiles) == 0
    msg := sprintf("Rule '%s' allows VPN access without HIP checks", [rule.name])
}

warn contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    svc := rule.service[_]
    is_admin_service(svc)
    not rule.mfa.required
    not contains(rule.name, "test")
    not contains(rule.name, "emergency")
    msg := sprintf("Rule '%s' allows admin access without MFA", [rule.name])
}

is_admin_service(svc) if {
    svc == "ssh"
}

is_admin_service(svc) if {
    svc == "tcp/22"
}

# ==============================================================================
# COMPLIANCE
# ==============================================================================

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    rule.tags.compliance == "pci-dss"
    not rule.log.atSessionStart
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing session-start logging", [rule.name])
}

deny contains msg if {
    rule := input.policies.security[_]
    rule.action == "allow"
    rule.enabled == true
    rule.tags.compliance == "pci-dss"
    not rule.dataFiltering
    not rule.securityProfiles.dataFiltering
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing data filtering/DLP", [rule.name])
}

# ==============================================================================
# NAT VALIDATION
# ==============================================================================

deny contains msg if {
    nat := input.policies.nat[_]
    nat.enabled == true
    nat.sourceTranslation.type == "dynamic-ip-and-port"
    nat.sourceAddress[_] == "any"
    msg := sprintf("NAT rule '%s' uses 'any' as source", [nat.name])
}

# ==============================================================================
# STATISTICS
# ==============================================================================

rule_count := count(input.policies.security)

allow_rule_count := count([rule | rule := input.policies.security[_]; rule.action == "allow"])

deny_rule_count := count([rule | rule := input.policies.security[_]; rule.action == "deny"]) +
                    count([rule | rule := input.policies.security[_]; rule.action == "drop"])

rules_with_profiles := count([rule |
    rule := input.policies.security[_]
    rule.action == "allow"
    has_critical_security_profiles(rule)
])

security_profile_coverage := (rules_with_profiles * 100) / allow_rule_count

summary := {
    "total_rules": rule_count,
    "allow_rules": allow_rule_count,
    "deny_rules": deny_rule_count,
    "rules_with_security_profiles": rules_with_profiles,
    "security_profile_coverage_percent": security_profile_coverage,
    "violations": count(deny),
    "warnings": count(warn)
}
