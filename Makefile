SHELL := /usr/bin/env bash
CONFIG_FILE := config.mk

ifeq ($(wildcard $(CONFIG_FILE)),)
$(error Run ./configure to generate $(CONFIG_FILE) before invoking make.)
endif

include $(CONFIG_FILE)

DOCKER ?= docker
UV ?= uv
DOCKER_BUILDKIT ?= 1
DOCKER_PROGRESS ?=

.PHONY: all help uv-lock uv-sync docker-build docker-run docker-push install clean dist-clean check \
	docker-buildx docker-buildx-local docker-pushx docker-prepull

all: docker-build

help:
	@awk -F':.*## ' '/^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' Makefile

uv-lock: ## Refresh uv.lock
	$(UV) lock

uv-sync: ## Create or update the local uv environment defined by UV_ENV
	UV_PROJECT_ENVIRONMENT=$(UV_ENV) $(UV) sync --locked --no-dev

docker-build: ## Build the container image
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) $(DOCKER) build \
		--file $(DOCKERFILE) \
		--tag $(IMAGE_REF) \
		$(if $(DOCKER_PROGRESS),--progress $(DOCKER_PROGRESS)) \
		$(DOCKER_CONTEXT)

docker-run: docker-build ## Run the container with GPU and notebook ports exposed
	$(DOCKER) run --rm -it --gpus all -p 8888:8888 $(IMAGE_REF)

docker-push: docker-build ## Push the container image to the configured registry
	$(DOCKER) push $(IMAGE_REF)

# Buildx with registry cache (shared across CI/local)
# Requires: docker buildx create --use (done automatically by first run if needed)
CACHE_REF ?= $(IMAGE_REF):buildcache

docker-buildx: ## Build with BuildKit and push/pull registry cache
	$(DOCKER) buildx inspect >/dev/null 2>&1 || $(DOCKER) buildx create --use
	$(DOCKER) buildx build \
		--file $(DOCKERFILE) \
		--tag $(IMAGE_REF) \
		--cache-from=type=registry,ref=$(CACHE_REF) \
		--cache-to=type=registry,ref=$(CACHE_REF),mode=max \
		$(if $(DOCKER_PROGRESS),--progress $(DOCKER_PROGRESS)) \
		--load \
		$(DOCKER_CONTEXT)

# Local persistent cache for fast developer iteration
LOCAL_CACHE_DIR ?= .buildx-cache

docker-buildx-local: ## Build with local cache (fast iteration)
	$(DOCKER) buildx inspect >/dev/null 2>&1 || $(DOCKER) buildx create --use
	$(DOCKER) buildx build \
		--file $(DOCKERFILE) \
		--tag $(IMAGE_REF) \
		--cache-from=type=local,src=$(LOCAL_CACHE_DIR) \
		--cache-to=type=local,dest=$(LOCAL_CACHE_DIR),mode=max \
		$(if $(DOCKER_PROGRESS),--progress $(DOCKER_PROGRESS)) \
		--load \
		$(DOCKER_CONTEXT)

docker-pushx: docker-buildx ## Push image (after buildx build)
	$(DOCKER) push $(IMAGE_REF)

# Optional: pre-pull and pin base images
BASE_IMAGE ?= nvcr.io/nvidia/pytorch:25.09-py3
UV_IMAGE ?= ghcr.io/astral-sh/uv:0.9.5

docker-prepull: ## Pre-pull base images to speed up builds
	$(DOCKER) pull $(BASE_IMAGE)
	$(DOCKER) pull $(UV_IMAGE)

install: docker-build ## Export the built image to a tarball
	mkdir -p $(DIST_DIR)
	$(DOCKER) save $(IMAGE_REF) -o $(DIST_IMAGE_TAR)
	@echo "Image saved to $(DIST_IMAGE_TAR)"

check: docker-build ## Sanity check the built image for CUDA-enabled torch
	$(DOCKER) run --rm $(IMAGE_REF) python -c "import torch; assert torch.version.cuda"

clean: ## Remove generated artifacts
	rm -rf $(DIST_DIR)

dist-clean: clean ## Remove build configuration
	rm -f $(CONFIG_FILE)
