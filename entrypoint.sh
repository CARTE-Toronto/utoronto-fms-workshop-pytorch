#!/usr/bin/env bash
set -euo pipefail

# Determine desired UID/GID from env or from the /workspace mount owner
TARGET_UID="${WORKSHOP_UID:-}"
TARGET_GID="${WORKSHOP_GID:-}"

if [[ -z "${TARGET_UID}" ]] && [[ -d "/workspace" ]]; then
    TARGET_UID="$(stat -c '%u' /workspace 2>/dev/null || echo 1000)"
fi
if [[ -z "${TARGET_GID}" ]] && [[ -d "/workspace" ]]; then
    TARGET_GID="$(stat -c '%g' /workspace 2>/dev/null || echo 1000)"
fi

TARGET_UID=${TARGET_UID:-1000}
TARGET_GID=${TARGET_GID:-1000}

# Ensure HOME points to a writable location on the bind mount
export HOME=/workspace
export USER=workshop

# Best-effort: make workshop home owned by target ids (non-fatal if chown fails)
chown -R "${TARGET_UID}:${TARGET_GID}" /home/workshop 2>/dev/null || true

# Drop privileges to the target numeric uid/gid without modifying system users
if command -v setpriv >/dev/null 2>&1; then
    exec setpriv --reuid "${TARGET_UID}" --regid "${TARGET_GID}" --init-groups "$@"
else
    echo "WARNING: setpriv not found; running as root may affect file permissions" >&2
    exec "$@"
fi


