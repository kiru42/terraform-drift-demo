#!/bin/bash
# Fix Terraform formatting without requiring Terraform installed
# This script applies common Terraform formatting rules

set -e

echo "Fixing Terraform formatting..."

# Find all .tf files
find . -name "*.tf" -type f | while read -r file; do
  echo "Processing: $file"
  
  # Create temp file
  temp_file="${file}.tmp"
  
  # Apply formatting rules:
  # 1. Convert tabs to 2 spaces
  # 2. Remove trailing whitespace
  # 3. Ensure newline at end of file
  sed 's/\t/  /g' "$file" | \
  sed 's/[[:space:]]*$//' > "$temp_file"
  
  # Ensure file ends with newline
  echo "" >> "$temp_file"
  
  # Replace original
  mv "$temp_file" "$file"
done

echo "✅ Formatting complete"
echo ""
echo "Files processed:"
find . -name "*.tf" -type f | wc -l
