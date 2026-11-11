#!/usr/bin/env bash
# Codespaces setup: installs kind, the Kyverno CLI (and kubectl if missing).
# Runs from .devcontainer/kyverno-policy-workshop/devcontainer.json.
set -euo pipefail
trap 'echo "::error::post-create.sh failed at line $LINENO: $BASH_COMMAND"' ERR
KIND_VERSION=v0.30.0
KYVERNO_VERSION=v1.19.1
KUBECTL_VERSION=v1.34.1
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then K_ARCH=amd64; C_ARCH=x86_64; else K_ARCH=arm64; C_ARCH=arm64; fi
SUDO=""; [[ $(id -u) -ne 0 ]] && SUDO=sudo
TMP=$(mktemp -d)

curl -fsSL -o "$TMP/kind" "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${K_ARCH}"
$SUDO install -m 0755 "$TMP/kind" /usr/local/bin/kind

curl -fsSL -o "$TMP/kyverno.tgz" "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/kyverno-cli_${KYVERNO_VERSION}_linux_${C_ARCH}.tar.gz"
tar xzf "$TMP/kyverno.tgz" -C "$TMP"
$SUDO install -m 0755 "$TMP/kyverno" /usr/local/bin/kyverno

if ! command -v kubectl >/dev/null 2>&1; then
  curl -fsSL -o "$TMP/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K_ARCH}/kubectl"
  $SUDO install -m 0755 "$TMP/kubectl" /usr/local/bin/kubectl
fi

if ! grep -q "kyverno lab" ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<'RC'
# kyverno lab
alias k=kubectl
source <(kubectl completion bash); complete -o default -F __start_kubectl k
cd /workspaces/*/kyverno-policy-workshop 2>/dev/null || true
RC
fi
echo "kind: $(kind version)"
echo "kyverno: $(kyverno version 2>&1 | grep -m1 Version || true)"
echo "kubectl: $(kubectl version --client 2>&1 | grep -m1 Client || true)"
