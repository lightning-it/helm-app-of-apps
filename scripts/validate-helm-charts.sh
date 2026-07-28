#!/usr/bin/env bash
set -euo pipefail

helm lint .
helm template adr-validation . >/dev/null
