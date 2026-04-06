.PHONY: init plan apply destroy clean validate drift

init:
	terraform init

plan:
	terraform plan -detailed-exitcode

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

clean:
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

validate:
	../scripts/validate-policy.sh desired-config.json

drift:
	@echo "Checking for drift..."
	@terraform plan -detailed-exitcode || (echo "⚠️  Drift detected!" && exit 1)

fmt:
	terraform fmt -recursive

refresh:
	terraform apply -refresh-only -auto-approve
