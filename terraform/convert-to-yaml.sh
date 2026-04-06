#!/bin/bash
# Convert desired-config.json to firewall-rules.yaml

set -e

cat > firewall-rules.yaml <<'EOF'
# Firewall Configuration
# This YAML file defines all firewall rules in a structured, readable format.
# 
# Security rules follow the principle of least privilege:
# - Explicit allow rules with security profiles
# - Deny rules for known-bad traffic
# - Logging for audit compliance

security_rules:
EOF

# Extract security rules
jq -r '.policies.security[] | @json' desired-config.json | while IFS= read -r rule; do
  name=$(echo "$rule" | jq -r '.name')
  
  echo "  - name: $name" >> firewall-rules.yaml
  echo "    source:" >> firewall-rules.yaml
  echo "$rule" | jq -r '.source[] | "      - \(.)"' >> firewall-rules.yaml
  echo "    destination:" >> firewall-rules.yaml
  echo "$rule" | jq -r '.destination[] | "      - \(.)"' >> firewall-rules.yaml
  echo "    service:" >> firewall-rules.yaml
  echo "$rule" | jq -r '.service[] | "      - \(.)"' >> firewall-rules.yaml
  
  # Application (optional)
  apps=$(echo "$rule" | jq -r '.application // [] | length')
  if [ "$apps" -gt 0 ]; then
    echo "    application:" >> firewall-rules.yaml
    echo "$rule" | jq -r '.application[] | "      - \(.)"' >> firewall-rules.yaml
  fi
  
  echo "    action: $(echo "$rule" | jq -r '.action')" >> firewall-rules.yaml
  echo "    enabled: $(echo "$rule" | jq -r '.enabled')" >> firewall-rules.yaml
  
  # Description
  desc=$(echo "$rule" | jq -r '.description // ""')
  if [ -n "$desc" ]; then
    echo "    description: \"$desc\"" >> firewall-rules.yaml
  fi
  
  # Tags
  echo "    tags:" >> firewall-rules.yaml
  echo "$rule" | jq -r '.tags | to_entries[] | "      \(.key): \(.value)"' >> firewall-rules.yaml
  
  # Log
  echo "    log:" >> firewall-rules.yaml
  echo "      at_session_start: $(echo "$rule" | jq -r '.log.atSessionStart // false')" >> firewall-rules.yaml
  echo "      at_session_end: $(echo "$rule" | jq -r '.log.atSessionEnd // true')" >> firewall-rules.yaml
  log_fwd=$(echo "$rule" | jq -r '.log.logForwarding // "null"')
  if [ "$log_fwd" != "null" ]; then
    echo "      log_forwarding: $log_fwd" >> firewall-rules.yaml
  fi
  
  # Security profiles (prefer securityProfiles object)
  has_profiles=$(echo "$rule" | jq -r '.securityProfiles != null')
  if [ "$has_profiles" = "true" ]; then
    echo "    security_profiles:" >> firewall-rules.yaml
    echo "$rule" | jq -r '.securityProfiles | to_entries[] | select(.value != null) | "      \(.key): \(.value)"' >> firewall-rules.yaml
  else
    # Fallback to flat structure
    av=$(echo "$rule" | jq -r '.antivirus // "null"')
    as=$(echo "$rule" | jq -r '.antiSpyware // "null"')
    vuln=$(echo "$rule" | jq -r '.vulnerability // "null"')
    
    if [ "$av" != "null" ] || [ "$as" != "null" ] || [ "$vuln" != "null" ]; then
      echo "    security_profiles:" >> firewall-rules.yaml
      [ "$av" != "null" ] && echo "      antivirus: $av" >> firewall-rules.yaml
      [ "$as" != "null" ] && echo "      antiSpyware: $as" >> firewall-rules.yaml
      [ "$vuln" != "null" ] && echo "      vulnerability: $vuln" >> firewall-rules.yaml
      
      # URL filtering (can be string or object)
      url=$(echo "$rule" | jq -r '.urlFiltering')
      if [ "$url" != "null" ]; then
        url_type=$(echo "$url" | jq -r 'type')
        if [ "$url_type" = "object" ]; then
          echo "      urlFiltering: $(echo "$url" | jq -r '.profile')" >> firewall-rules.yaml
        else
          echo "      urlFiltering: $url" >> firewall-rules.yaml
        fi
      fi
      
      fb=$(echo "$rule" | jq -r '.fileBlocking // "null"')
      [ "$fb" != "null" ] && echo "      fileBlocking: $fb" >> firewall-rules.yaml
      
      wf=$(echo "$rule" | jq -r '.wildfire // "null"')
      [ "$wf" != "null" ] && echo "      wildfire: $wf" >> firewall-rules.yaml
      
      df=$(echo "$rule" | jq -r '.dataFiltering // "null"')
      [ "$df" != "null" ] && echo "      dataFiltering: $df" >> firewall-rules.yaml
    fi
  fi
  
  echo "" >> firewall-rules.yaml
done

echo "✅ Converted to firewall-rules.yaml"
