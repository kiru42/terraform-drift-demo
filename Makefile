.PHONY: help install build start-api test-api test validate validate-opa e2e clean

help:
	@echo "Terraform Drift Detection Demo - Available Commands:"
	@echo ""
	@echo "  make install       - Install all dependencies"
	@echo "  make build         - Build the mock API"
	@echo "  make start-api     - Start the mock Panorama API"
	@echo "  make test-api      - Run API unit tests"
	@echo "  make test          - Run all tests"
	@echo "  make validate      - Run basic policy validation (bash)"
	@echo "  make validate-opa  - Run advanced OPA policy validation"
	@echo "  make e2e           - Run end-to-end drift detection test"
	@echo "  make clean         - Clean build artifacts and dependencies"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make install"
	@echo "  2. make start-api   (in one terminal)"
	@echo "  3. make e2e         (in another terminal)"
	@echo ""
	@echo "Policy Validation:"
	@echo "  make validate      - Quick bash validation"
	@echo "  make validate-opa  - Advanced OPA validation (requires OPA)"

install:
	@echo "Installing dependencies..."
	cd mock-panorama && npm install

build:
	@echo "Building TypeScript..."
	cd mock-panorama && npm run build

start-api:
	@echo "Starting Mock Panorama API on port 3000..."
	cd mock-panorama && npm start

test-api:
	@echo "Running API unit tests..."
	cd mock-panorama && npm test

validate:
	@echo "Running basic policy validation..."
	./scripts/validate-policy.sh terraform/desired-config.json

validate-opa:
	@echo "Running OPA policy validation..."
	./scripts/validate-opa.sh terraform/desired-config.json

test: test-api validate
	@echo "Running Terraform validation..."
	cd terraform && terraform fmt -check
	@echo "All tests passed!"

e2e:
	@echo "Running end-to-end drift detection test..."
	./scripts/e2e-test.sh

clean:
	@echo "Cleaning build artifacts..."
	rm -rf mock-panorama/node_modules
	rm -rf mock-panorama/dist
	rm -rf mock-panorama/coverage
	cd terraform && rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
	@echo "Clean complete!"
