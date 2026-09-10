APP_NAME := lab-node
IMAGE_NAME := $(APP_NAME):v1
NAMESPACE := seguridad
PWD := $(shell pwd)
TRIVY_CACHE := $(PWD)/.cache/trivy
REPORTS := $(PWD)/reports
GATE_SEVERITY ?= CRITICAL

SEMGREP_IMAGE ?= semgrep/semgrep:latest
TRIVY_IMAGE ?= aquasec/trivy:latest
SYFT_IMAGE ?= anchore/syft:latest

.PHONY: help preflight sast sca sbom build image-scan security-gate \
        cluster deploy dast pipeline clean reset

help:
	@echo "Secure CI/CD Lab"
	@echo ""
	@echo "  make preflight       Verify local prerequisites"
	@echo "  make sast            Run deterministic Semgrep SAST rule"
	@echo "  make sca             Scan dependencies/secrets with Trivy"
	@echo "  make sbom            Generate CycloneDX SBOM"
	@echo "  make build           Build lab-node:v1"
	@echo "  make image-scan      Scan HIGH/CRITICAL image findings"
	@echo "  make security-gate   Block EOL OS or $(GATE_SEVERITY) OS CVEs"
	@echo "  make cluster         Start/check Minikube"
	@echo "  make deploy          Load image and deploy to Kubernetes"
	@echo "  make dast            Run deterministic Nuclei test in cluster"
	@echo "  make pipeline        SAST -> SCA -> SBOM -> BUILD -> IMAGE -> GATE -> DEPLOY"
	@echo "  make clean           Remove Kubernetes lab resources"

preflight:
	@command -v docker >/dev/null || (echo "ERROR: docker not found"; exit 1)
	@command -v kubectl >/dev/null || (echo "ERROR: kubectl not found"; exit 1)
	@command -v minikube >/dev/null || (echo "ERROR: minikube not found"; exit 1)
	@docker info >/dev/null 2>&1 || (echo "ERROR: Docker daemon is not running"; exit 1)
	@mkdir -p "$(TRIVY_CACHE)" "$(REPORTS)"
	@echo "Preflight: OK"

sast:
	@echo "\n[1] SAST - Semgrep"
	docker run --rm \
		-v "$(PWD)/app:/src" \
		-v "$(PWD)/.semgrep:/rules:ro" \
		$(SEMGREP_IMAGE) \
		semgrep --config=/rules/lasalle-rules.yml /src

sca:
	@echo "\n[2] SCA / Secrets - Trivy filesystem"
	@mkdir -p "$(TRIVY_CACHE)" "$(REPORTS)"
	docker run --rm \
		-v "$(PWD)/app:/app:ro" \
		-v "$(TRIVY_CACHE):/root/.cache/" \
		$(TRIVY_IMAGE) \
		fs --scanners vuln,secret /app

sbom:
	@echo "\n[3] SBOM - Syft / CycloneDX"
	@mkdir -p "$(REPORTS)"
	docker run --rm \
		-v "$(PWD)/app:/src:ro" \
		-v "$(REPORTS):/reports" \
		$(SYFT_IMAGE) \
		dir:/src -o cyclonedx-json=/reports/sbom.cdx.json
	@echo "SBOM: reports/sbom.cdx.json"

build:
	@echo "\n[4] BUILD - Docker"
	docker build -t $(IMAGE_NAME) ./app

image-scan:
	@echo "\n[5] IMAGE SCAN - Trivy"
	@mkdir -p "$(TRIVY_CACHE)"
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "$(TRIVY_CACHE):/root/.cache/" \
		$(TRIVY_IMAGE) \
		image --severity HIGH,CRITICAL $(IMAGE_NAME)

security-gate:
	@echo "\n[6] SECURITY GATE"
	@echo "Policy: BLOCK if base OS is EOL or contains $(GATE_SEVERITY) OS vulnerabilities."
	@mkdir -p "$(TRIVY_CACHE)"
	@docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "$(TRIVY_CACHE):/root/.cache/" \
		$(TRIVY_IMAGE) \
		image --scanners vuln --pkg-types os \
		--severity $(GATE_SEVERITY) --exit-code 1 --exit-on-eol 1 \
		$(IMAGE_NAME) \
	&& echo "SECURITY GATE: PASSED" \
	|| (echo "SECURITY GATE: FAILED"; \
	    echo "DEPLOYMENT BLOCKED"; \
	    echo ""; \
	    echo "This may be the expected result of the first lab run."; \
	    echo "1. Identify why the artifact violated policy."; \
	    echo "2. Remediate the finding in your Git branch."; \
	    echo "3. Rebuild and run the gate again."; \
	    exit 1)

cluster:
	@echo "\n[K8S] Checking Minikube"
	@minikube status >/dev/null 2>&1 || minikube start --driver=docker --cpus=4 --memory=8192
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

deploy: cluster
	@echo "\n[7] DEPLOY - Kubernetes"
	minikube image load $(IMAGE_NAME)
	kubectl apply -n $(NAMESPACE) -f k8s/app-deploy.yaml
	kubectl rollout status -n $(NAMESPACE) deployment/vuln-node-app --timeout=120s
	@echo "Application URL:"
	@minikube service -n $(NAMESPACE) vuln-node-service --url

dast:
	@echo "\n[8] DAST - Nuclei"
	@kubectl get namespace $(NAMESPACE) >/dev/null 2>&1 || (echo "ERROR: run 'make deploy' first"; exit 1)
	kubectl create configmap nuclei-lab-template -n $(NAMESPACE) \
		--from-file=lasalle-reflected-input.yaml=nuclei/lasalle-reflected-input.yaml \
		--dry-run=client -o yaml | kubectl apply -f -
	-kubectl delete job nuclei-scan -n $(NAMESPACE) --ignore-not-found
	kubectl apply -n $(NAMESPACE) -f k8s/nuclei-job.yaml
	kubectl wait -n $(NAMESPACE) --for=condition=complete job/nuclei-scan --timeout=180s
	@echo "Nuclei result:"
	@kubectl logs -n $(NAMESPACE) job/nuclei-scan

pipeline: preflight
	@echo "========================================"
	@echo "       SECURE CI/CD PIPELINE"
	@echo "========================================"
	@$(MAKE) sast
	@$(MAKE) sca
	@$(MAKE) sbom
	@$(MAKE) build
	@$(MAKE) image-scan
	@$(MAKE) security-gate
	@$(MAKE) deploy
	@echo "========================================"
	@echo "PIPELINE: PASSED"
	@echo "Run 'make dast' for post-deployment DAST."
	@echo "========================================"

clean:
	-kubectl delete job nuclei-scan -n $(NAMESPACE) --ignore-not-found
	-kubectl delete configmap nuclei-lab-template -n $(NAMESPACE) --ignore-not-found
	-kubectl delete -n $(NAMESPACE) -f k8s/app-deploy.yaml --ignore-not-found

reset: clean
	-minikube delete
