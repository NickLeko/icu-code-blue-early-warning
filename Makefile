smoke:
	bash scripts/smoke_check.sh

prepare:
	@if [ -z "$(PROJECT_ID)" ]; then echo "Usage: make prepare PROJECT_ID=my-gcp-project"; exit 1; fi
	bash scripts/prepare_sql.sh "$(PROJECT_ID)"
