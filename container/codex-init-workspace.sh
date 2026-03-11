#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="/workspace"
QUIET=0

usage() {
  cat <<USAGE
Usage:
  $0 [--workspace DIR] [--force] [--quiet]

Options:
  --workspace DIR   Target workspace path (default: /workspace)
  --force           Accepted for compatibility; no longer has an effect
  --quiet           Suppress non-error output
USAGE
}

info() {
  [[ "$QUIET" -eq 1 ]] || echo "$*"
}

warn() {
  echo "$*" >&2
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --workspace)
        WORKSPACE_ROOT="$2"
        shift 2
        ;;
      --force)
        shift
        ;;
      --quiet)
        QUIET=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        warn "unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  warn "codex-init-workspace is a compatibility redirect in toolbelt."
  warn "Toolbelt no longer seeds coordinator assets; use the standalone /workspace/coordinator repository."
  info "Requested workspace: $WORKSPACE_ROOT"
  info "Next step: mount or clone coordinator at /workspace/coordinator and run its scripts directly."
  exit 1
}

main "$@"
