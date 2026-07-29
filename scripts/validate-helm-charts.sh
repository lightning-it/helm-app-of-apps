#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v helm >/dev/null 2>&1 || {
  echo "helm is required" >&2
  exit 1
}
command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl with built-in kustomize support is required" >&2
  exit 1
}

render_dir="$(mktemp -d)"
trap 'rm -rf "$render_dir"' EXIT

helm lint .
helm template lit-quality . \
  --set-string global.envName=cluster-dev-com \
  --set-string global.baseDomain=example.invalid \
  | grep -q '^kind: Application$'

shopt -s nullglob
cluster_values=(cluster/*/values.yaml)
if [[ "${#cluster_values[@]}" -eq 0 ]]; then
  echo "no cluster values files found" >&2
  exit 1
fi

cluster_count=0
for values_file in "${cluster_values[@]}"; do
  cluster_name="$(basename "$(dirname "$values_file")")"
  rendered="$render_dir/${cluster_name}.yaml"

  helm lint . --values "$values_file"
  helm template "lit-${cluster_name}" . --values "$values_file" >"$rendered"

  application_count="$(grep -c '^kind: Application$' "$rendered" || true)"
  if [[ "$application_count" -eq 0 ]]; then
    echo "${values_file}: rendered no Argo CD Applications" >&2
    exit 1
  fi

  if grep -Eq \
    '^[[:space:]]*targetRevision:[[:space:]]*(HEAD|latest)([[:space:]#]|$)' \
    "$rendered"; then
    echo "${values_file}: rendered an implicit or floating targetRevision" >&2
    exit 1
  fi

  prune_count="$(grep -c '^[[:space:]]*prune: true$' "$rendered" || true)"
  self_heal_count="$(grep -c '^[[:space:]]*selfHeal: true$' "$rendered" || true)"
  if [[ "$prune_count" -ne "$application_count" ]] \
    || [[ "$self_heal_count" -ne "$application_count" ]]; then
    echo "${values_file}: every Application must enable prune and self-heal" >&2
    exit 1
  fi

  cluster_count=$((cluster_count + 1))
done

overlay_count=0
while IFS= read -r overlay; do
  kubectl kustomize "$overlay" >"$render_dir/kustomize-${overlay_count}.yaml"
  overlay_count=$((overlay_count + 1))
done < <(find kustomize -type d -path '*/overlays/*' -mindepth 3 -maxdepth 3 | sort)

if [[ "$overlay_count" -eq 0 ]]; then
  echo "no Kustomize overlays found" >&2
  exit 1
fi

echo "validated ${cluster_count} cluster values files and ${overlay_count} Kustomize overlays"
