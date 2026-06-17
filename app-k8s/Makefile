# ==============================================================================
# Makefile — duoc/intro-devops
#
# Automates "Actividad 2: Actualizar imágenes en ECR para EKS":
#   1. ECR login
#   2. Build, tag, and push frontend / backend / db images to ECR
#
# Usage:
#   make help                          # show this help
#   make account=637083690819 login    # Paso 1
#   make account=637083690819 publish-frontend tag=eks-v1
#   make account=637083690819 publish-all tag=eks-v1
#
# Variables (override on the command line or via env):
#   account  — AWS account ID (required for login/push; build alone does
#              not need it). Example: 637083690819
#   tag      — image tag to apply. Default: eks-v1
#   region   — AWS region for ECR. Default: us-east-1
#   source   — directory holding the per-service Dockerfiles.
#              Default: project/app-k8s
# ==============================================================================

# --- Required toolchain -----------------------------------------------------
DOCKER       ?= docker
AWS          ?= aws

# --- Configuration ----------------------------------------------------------
region       ?= us-east-1
tag          ?= eks-v1
source       ?= .

# Services in the order the activity walks through them. To add a new
# service, drop a directory in $(source) and add its name here.
services     := frontend backend db

# Composed targets
ECR_REGISTRY := $(account).dkr.ecr.$(region).amazonaws.com

# --- Phony / safety ---------------------------------------------------------
.PHONY: help login build build-all tag tag-all push push-all \
        publish publish-all clean check-account check-docker

# Default target: show the help.
help:
	@echo "Actividad 2 — Actualizar imágenes en ECR para EKS"
	@echo
	@echo "Variables:"
	@echo "  account  AWS account ID  (REQUIRED for login / push)        [$(account)]"
	@echo "  tag      Image tag                                       [$(tag)]"
	@echo "  region   AWS region                                      [$(region)]"
	@echo "  source   Directory holding per-service Dockerfiles        [$(source)]"
	@echo
	@echo "Pasos:"
	@echo "  make account=<ID> login                            # Paso 1: login en ECR"
	@echo "  make account=<ID> publish-frontend tag=eks-v1      # build+tag+push de un servicio"
	@echo "  make account=<ID> publish-all tag=eks-v1           # los tres servicios"
	@echo
	@echo "Granular (build / tag / push por separado):"
	@echo "  make build-<service>            # sólo docker build"
	@echo "  make tag-<service> account=…    # sólo docker tag"
	@echo "  make push-<service> account=…   # sólo docker push"
	@echo
	@echo "Bulk:"
	@echo "  make build-all                  # construye todas las imágenes locales"
	@echo "  make tag-all    account=…       # taggea todas apuntando a ECR"
	@echo "  make push-all   account=…       # sube todas a ECR"
	@echo
	@echo "Mantenimiento:"
	@echo "  make clean                      # borra las imágenes locales taggeadas"
	@echo
	@echo "Servicios configurados: $(services)"
	@echo "Source dir:            $(abspath $(source))"

# --- Tooling checks ---------------------------------------------------------
check-docker:
	@command -v $(DOCKER) >/dev/null 2>&1 || { \
		echo "ERROR: $(DOCKER) no está instalado o no está en PATH"; exit 1; }
	@command -v $(AWS) >/dev/null 2>&1 || { \
		echo "ERROR: $(AWS) CLI no está instalado o no está en PATH"; exit 1; }

# Fails fast if `account` is empty or non-numeric. Skipped by the build-only
# targets, which don't need an account.
check-account:
	@if [ -z "$(account)" ]; then \
		echo "ERROR: variable 'account' no está definida."; \
		echo "  Uso:  make account=<tu-account-id> login"; \
		echo "  Ej:   make account=637083690819 login"; \
		exit 1; \
	fi
	@echo "$(account)" | grep -Eq '^[0-9]{12}$$' || { \
		echo "ERROR: 'account=$(account)' no parece un AWS account ID válido (12 dígitos)."; \
		exit 1; \
	}

# ==============================================================================
# PASO 1 — ECR LOGIN
# ==============================================================================
login: check-docker check-account
	@echo "[login] Autenticando Docker contra $(ECR_REGISTRY)…"
	@$(AWS) ecr get-login-password --region $(region) \
		| $(DOCKER) login --username AWS --password-stdin $(ECR_REGISTRY)
	@echo "[login] OK — Docker puede hacer push a $(ECR_REGISTRY)"

# ==============================================================================
# BUILD (local) — Paso 2/3/4, paso 1 de cada servicio
# Construye la imagen local con el nombre simple (tienda-<service>).
# No necesita `account`.
# ==============================================================================
build: build-all
build-all: $(addprefix build-,$(services))

build-%: check-docker
	@echo "[build] Construyendo tienda-$* desde $(source)/$*…"
	@cd $(source)/$* && $(DOCKER) build -t tienda-$* .
	@echo "[build] OK — tienda-$* construida localmente"

# ==============================================================================
# TAG — Paso 2/3/4, paso 2 de cada servicio
# Crea el tag apuntando a ECR. Requiere `account`.
# ==============================================================================
tag: tag-all
tag-all: $(addprefix tag-,$(services))

tag-%: check-docker check-account
	@echo "[tag] Etiquetando tienda-$*:$(tag) -> $(ECR_REGISTRY)/tienda-$*:$(tag)"
	@$(DOCKER) tag tienda-$*:latest $(ECR_REGISTRY)/tienda-$*:$(tag)
	@echo "[tag] OK"

# ==============================================================================
# PUSH — Paso 2/3/4, paso 3 de cada servicio
# ==============================================================================
push: push-all
push-all: $(addprefix push-,$(services))

push-%: check-docker check-account
	@echo "[push] Subiendo $(ECR_REGISTRY)/tienda-$*:$(tag) a ECR…"
	@$(DOCKER) push $(ECR_REGISTRY)/tienda-$*:$(tag)
	@echo "[push] OK — $(ECR_REGISTRY)/tienda-$*:$(tag)"

# ==============================================================================
# PUBLISH — atajo que combina build + tag + push
# ==============================================================================
publish: publish-all
publish-all: login $(addprefix publish-,$(services))

publish-%: login
	@$(MAKE) --no-print-directory build-$* tag-$* push-$*

# ==============================================================================
# CLEAN — borra las imágenes locales (no toca ECR).
# No requiere `account` porque opera sólo sobre imágenes locales
# taggeadas con el nombre simple (tienda-<service>). Si `account` está
# definido, también borra los tags apuntando a ECR.
# ==============================================================================
clean: check-docker
	@echo "[clean] Eliminando imágenes locales tienda-*…"
	@for s in $(services); do \
		$(DOCKER) rmi -f tienda-$$s:latest 2>/dev/null || true; \
		if [ -n "$(account)" ]; then \
			$(DOCKER) rmi -f $(ECR_REGISTRY)/tienda-$$s:$(tag) 2>/dev/null || true; \
		fi; \
	done
	@echo "[clean] OK"
