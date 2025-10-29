# UofT FMS Workshop – PyTorch Container

This repository builds and publishes the GPU-enabled Docker image used for the University of Toronto Foundation Models for Science workshop. The image layers a curated Python environment (managed by `uv`) on top of NVIDIA's PyTorch base, giving participants a turnkey JupyterLab setup with CUDA-ready `torch`, `transformers`, and common data science tooling.

## Prerequisites

- Docker with BuildKit support (Docker Engine 20.10+ recommended)
- Bash-compatible shell
- Optional: [`uv`](https://docs.astral.sh/uv/) if you plan to refresh or audit the dependency lockfile locally

## Quick Start

```bash
./configure                     # generates config.mk with sensible defaults
make docker-build               # builds ghcr.io/carte-toronto/utoronto-fms-workshop-pytorch:latest
make docker-run                 # launches the image with GPU access and Jupyter port 8888
```

`./configure` writes `config.mk`; all `make` targets require this file. Re-run `./configure` whenever you need to change image settings (name, tag, registry, build context, etc.).

### Common Configure Flags

- `--image-tag 2024.10.31` – tag the build for a specific workshop date
- `--registry ghcr.io/your-org` – push to a different GHCR namespace
- `--no-registry` – publish to Docker Hub or keep the image local
- `--progress plain` – expose verbose BuildKit output during local builds

Run `./configure --help` for the full option list.

### Notable Make Targets

- `make` / `make docker-build` – builds the container image referenced in `config.mk`
- `make docker-push` – pushes the built image to the configured registry
- `make docker-run` – runs the image with GPU support for quick smoke tests
- `make check` – verifies `torch.version.cuda` inside the image
- `make uv-lock` – refreshes `uv.lock` if dependency changes are needed
- `make install` – exports the built image to `dist/<image>-<tag>.tar`

The Makefile uses BuildKit and respects environment overrides such as `DOCKER`, `UV`, and `DOCKER_PROGRESS`. Consult `make help` to see the annotated target list.

## Updating Dependencies

Dependency versions live in `pyproject.toml`, while the resolved lock lives in `uv.lock`. To add or bump packages:

1. Edit `pyproject.toml`
2. Run `make uv-lock` (or `uv lock`) to refresh the lockfile
3. Rebuild the image with `make docker-build`

The Dockerfile fails the build if `torch.version.cuda` is empty, ensuring CUDA-enabled wheels remain selected.

## Publishing Images

CI builds routinely run out of disk when pulling NVIDIA's PyTorch base images on hosted runners. Push releases from a local machine or self-hosted runner instead:

1. Run `./configure` with the desired `--image-tag` and registry overrides.
2. Authenticate to your registry (`docker login ghcr.io` for GitHub Container Registry).
3. Execute `make docker-push` to build and publish the image.

## Further Reading

- `models.md` – background on design decisions and dependency choices
- `configure` – full CLI for generating `config.mk`
- `Makefile` – documented targets and environment overrides for image lifecycle management
