# Makefile para LaSalleSDLC

APP_NAME=lab-node
IMAGE_NAME=$(APP_NAME):v1

.PHONY: build scan-semgrep scan-trivy run-scans deploy-app delete-app open-ui

build:
	cd app && docker build -t $(IMAGE_NAME) .

scan-semgrep:
	docker run --rm -v ${PWD}/app:/src returntocorp/semgrep semgrep --config=auto /src

scan-trivy:
	trivy fs ./app

run-scans: scan-semgrep scan-trivy

deploy-app:
	kubectl apply -f app-deploy.yaml

delete-app:
	kubectl delete -f app-deploy.yaml

open-ui:
	kubectl -n argo port-forward svc/argo-server 2746:2746
