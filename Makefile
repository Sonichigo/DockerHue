CONFTEST_IMAGE := openpolicyagent/conftest:v0.56.0

.PHONY: policy up down status

# The gate: every Dockerfile under services/ must pass policy/dockerfile.rego.
policy:
	docker run --rm -v "$(CURDIR)":/project -w /project $(CONFTEST_IMAGE) \
		test --policy policy services/*/Dockerfile

# Nothing builds or runs unless the policy passes.
up: policy
	docker compose up --build -d
	@echo "dockerhue is up -> curl localhost:8080/api"

down:
	docker compose down

status:
	docker compose ps
	curl -s localhost:8080/api
