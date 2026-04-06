# OPA Policy Validation

This directory contains **Open Policy Agent (OPA)** policies for validating firewall configurations.

## Quick Start

```bash
# Run validation
./scripts/validate-opa.sh

# Or manually
opa eval --data opa/policies/firewall-security.rego \
         --input terraform/desired-config.json \
         --format pretty 'data.firewall.security'
```

## Policy Structure

```
opa/
├── policies/
│   └── firewall-security.rego    # Main security policy
└── tests/
    └── firewall-security_test.rego (optional)
```

## What the Policy Validates

### Deny Rules (Violations)
1. ❌ Blanket allow-all rules (`any → any → any`)
2. ❌ Rules without descriptions
3. ❌ Allow rules without security profiles (AV, AS, VUL)
4. ❌ Outbound traffic without logging
5. ❌ External SSH access to internal networks
6. ❌ P2P/Torrent applications allowed
7. ❌ Risky remote access tools (TeamViewer, Tor)
8. ❌ PCI-DSS rules without enhanced logging
9. ❌ PCI-DSS rules without DLP
10. ❌ HIPAA rules without PHI protection
11. ❌ SNAT with "any" source address

### Warn Rules (Best Practices)
1. ⚠️ Rules without tags
2. ⚠️ Web traffic without URL filtering
3. ⚠️ File transfer without WildFire
4. ⚠️ DMZ traffic without strict profiles
5. ⚠️ VPN access without HIP checks
6. ⚠️ Admin access without MFA
7. ⚠️ DNAT without matching security rule
8. ⚠️ Decrypting financial/healthcare sites

## Custom Policy Development

### Add a New Rule

Edit `policies/firewall-security.rego`:

```rego
# Deny: Custom rule example
deny[msg] {
    some rule in input.policies.security
    # Your conditions here
    
    msg := sprintf("Rule '%s' violates policy", [rule.name])
}
```

### Test Your Policy

```bash
# Check syntax
opa check opa/policies/firewall-security.rego

# Run validation
./scripts/validate-opa.sh
```

## Documentation

See [OPA-VALIDATION.md](../docs/OPA-VALIDATION.md) for complete guide.

## Resources

- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Policy Examples](https://github.com/open-policy-agent/library)
