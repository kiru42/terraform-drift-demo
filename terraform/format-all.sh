#!/bin/bash
# Format all Terraform files

set -e

echo "Formatting Terraform files..."

# Format root
for file in *.tf; do
  if [ -f "$file" ]; then
    echo "Formatting $file"
    cat "$file" | sed 's/\t/  /g' > "${file}.tmp"
    mv "${file}.tmp" "$file"
  fi
done

# Format modules
for module in modules/*/; do
  if [ -d "$module" ]; then
    echo "Formatting $module"
    for file in "$module"*.tf; do
      if [ -f "$file" ]; then
        cat "$file" | sed 's/\t/  /g' > "${file}.tmp"
        mv "${file}.tmp" "$file"
      fi
    done
  fi
done

# Format environments
for env in environments/*/; do
  if [ -d "$env" ]; then
    echo "Formatting $env"
    for file in "$env"*.tf; do
      if [ -f "$file" ]; then
        cat "$file" | sed 's/\t/  /g' > "${file}.tmp"
        mv "${file}.tmp" "$file"
      fi
    done
  fi
done

echo "✅ All files processed"
