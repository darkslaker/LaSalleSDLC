# Makefile para laboratorio LaSalleSDLC

APP_NAME=lab-node
IMAGE_NAME=$(APP_NAME):v1

.PHONY: all build scan-semgrep scan-trivy run-scans

all: build run-scans

build:
	cd app && docker build -t $(IMAGE_NAME) .

scan-semgrep:
	docker run --rm -v ${PWD}/app:/src returntocorp/semgrep semgrep --config=auto /src

scan-trivy:
	trivy fs ./app

run-scans: scan-semgrep scan-trivy
