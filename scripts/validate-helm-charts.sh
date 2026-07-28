#!/usr/bin/env bash
set -euo pipefail

helm lint .
helm template lit-quality . >/dev/null
helm template lit-quality . \
  --set-string global.envName=cluster-dev-com \
  --set-string global.baseDomain=example.invalid \
  | grep -q '^kind: Application$'
