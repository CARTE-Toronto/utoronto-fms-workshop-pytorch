# syntax=docker/dockerfile:1.9

ARG BASE_IMAGE=nvcr.io/nvidia/pytorch:25.09-py3
ARG UV_VERSION=0.9.5
ARG UV_IMAGE=ghcr.io/astral-sh/uv:${UV_VERSION}

FROM ${UV_IMAGE} AS uv-dist

FROM ${BASE_IMAGE} AS runtime

# Copy the uv and uvx binaries from the pinned distribution image
COPY --from=uv-dist /uv /usr/local/bin/
COPY --from=uv-dist /uvx /usr/local/bin/

# Create an unprivileged user for running the workshop services
RUN (groupadd --system --gid 1000 workshop || groupadd --system workshop) \
    && (useradd --system --gid workshop --uid 1000 --create-home workshop \
        || useradd --system --gid workshop --create-home workshop)

WORKDIR /workspace

# Configure uv for deterministic builds that hit the GPU-enabled torch wheel
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    PATH="/opt/venv/bin:${PATH}"

# Resolve and download all dependencies first to maximize layer reuse
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv sync --locked --no-install-project --no-dev

# Copy the project and perform the final sync into the frozen environment
COPY --chown=workshop:workshop . /workspace
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev \
    && chown -R workshop:workshop /opt/venv

# Provide Jupyter server configuration (disable unavailable extensions)
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Fail fast if the CUDA-enabled torch wheel was selected (no GPU required)
RUN python - <<'PY'
import torch
cuda_ver = torch.version.cuda or ""
assert cuda_ver.startswith("12.4"), f"Expected CUDA 12.4 torch build, got: {cuda_ver!r}"
PY

EXPOSE 8888

USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
