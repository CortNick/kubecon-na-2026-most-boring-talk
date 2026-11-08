#!/usr/bin/env bash
# Codespaces setup: installs the CLIs the workshop needs on top of the dev container features.
# Runs from .devcontainer/backstage-dr-workshop/devcontainer.json at the repository root.
set -euo pipefail

source "$(dirname "$0")/versions.env"

ARCH="$(dpkg --print-architecture)" # amd64 or arm64

# The dev container base image already has jq; 'apt-get update' alone costs several seconds.
if ! command -v jq >/dev/null; then
  echo "==> Installing jq"
  sudo apt-get update -qq && sudo apt-get install -y -qq jq >/dev/null
fi

echo "==> Installing kind ${KIND_VERSION}"
curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors -o /tmp/kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${ARCH}"
sudo install -m 0755 /tmp/kind /usr/local/bin/kind

echo "==> Tool versions"
kind version
kubectl version --client
jq --version

# Write the guided tour now, so CodeTour finds it when the editor opens.
bash "$(dirname "$0")/render-tour.sh"

echo
echo "Tools installed. Next: creating the workshop cluster and starting Backstage."
