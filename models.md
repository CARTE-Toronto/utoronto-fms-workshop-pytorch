# UofT FMS Workshop Docker Image

This repository (`utoronto-fms-workshop-pytorch`) contains the Dockerfile and associated files to build a custom NVIDIA PyTorch-based image for the University of Toronto Foundation Models for Science workshop.

## Task

The goal is to create a Docker image that includes the following pre-installed packages:
- jupyterlab
- transformers
- torch (with GPU support)

## Plan

1. **Create `pyproject.toml`:** Declare project dependencies and configure uv to favor the CUDA wheel index:
   ```toml
   [project]
   dependencies = [
       "datasets==3.0.1",
       "jupyterlab==4.2.5",
       "matplotlib==3.9.2",
       "numpy==2.1.2",
       "pandas==2.2.3",
       "requests==2.32.3",
       "scikit-learn==1.5.2",
       "seaborn==0.13.2",
       "torch==2.5.1",
       "tqdm==4.66.5",
       "transformers==4.45.2"
   ]

   [tool.uv.pip]
   index-url = "https://download.pytorch.org/whl/cu130"
   extra-index-url = ["https://pypi.org/simple"]
   ```
   Making the CUDA index the default ensures GPU wheels are selected first, while PyPI remains available for the rest of the ecosystem.
2. **Author the Dockerfile:** Use `nvcr.io/nvidia/pytorch:25.09-py3` (CUDA 13.0) as the base image so matching toolkits and GPU drivers are preinstalled.
3. **Install uv:** Copy pinned `uv` and `uvx` binaries from the `ghcr.io/astral-sh/uv:0.9.5` distribution image.
4. **Generate `uv.lock` locally:** Run `uv lock` in this repository so dependency resolution (including CUDA wheels) happens once, outside of the Docker build.
5. **Copy project metadata:** Copy both `pyproject.toml` and the newly generated `uv.lock` into the image.
6. **Sync dependencies:** Execute `uv sync --frozen` so all packages, including GPU-enabled PyTorch, install deterministically from the lockfile.
7. **Validate CUDA availability:** Fail the build if `torch.version.cuda` is empty to ensure a CUDA-enabled wheel was installed without requiring a GPU.
8. **Build (and optionally push) the image:** Use the generated make targets to build, export, and distribute the container image.

## Build Workflow

This repository now provides a conventional `./configure` / `make` / `make install` workflow:

- Run `./configure [options]` to generate `config.mk` with your desired image name, tag, registry, and artifact directory.
- By default images are tagged under `ghcr.io/CARTE-Toronto`; use `--registry <value>` or `--no-registry` to override.
- Use `make` (or `make docker-build`) to build the image with BuildKit, fully leveraging the uv-managed dependency caching baked into the `Dockerfile`.
- Invoke `make uv-sync` for a local `uv sync --locked --no-dev`, or `make uv-lock` to refresh `uv.lock`.
- Execute `make install` to export the built image as a tarball under `dist/`.

## Current Status

- `Dockerfile` uses `nvcr.io/nvidia/pytorch:25.09-py3` with CUDA 13.0, copies uv binaries from `ghcr.io/astral-sh/uv:0.9.5`, performs staged `uv sync` operations with cache mounts, and validates the CUDA-enabled torch wheel.
- `configure` writes `config.mk` with sensible defaults (including the CARTE-Toronto GHCR namespace) and supports overrides for image name, tag, registry, context, and uv environment.
- `Makefile` exposes `make`, `make install`, `make uv-sync`, `make uv-lock`, `make docker-run`, and `make check`, enabling a standard configure/make workflow.
- `pyproject.toml` and `uv.lock` pin the workshop dependencies, prioritized for CUDA-enabled PyTorch wheels via the configured indices.
