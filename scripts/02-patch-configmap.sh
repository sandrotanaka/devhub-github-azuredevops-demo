#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# 02-patch-configmap.sh
# Adiciona app-config.azure.yaml ao ConfigMap do RHDH
# Uso: source .env && bash scripts/02-patch-configmap.sh
# =============================================================

: "${OCP_NAMESPACE:?Variável OCP_NAMESPACE não definida. Execute: source .env}"
: "${RHDH_CONFIGMAP_APPCONFIG:?Variável RHDH_CONFIGMAP_APPCONFIG não definida. Execute: source .env}"
: "${AZURE_DEVOPS_PAT:?Variável AZURE_DEVOPS_PAT não definida. Execute: source .env}"
: "${GITHUB_USER:?Variável GITHUB_USER não definida. Execute: source .env}"

echo "→ Verificando login no OpenShift..."
oc whoami > /dev/null || { echo "ERRO: não autenticado. Execute 'oc login' primeiro."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/app-config.azure.yaml"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERRO: arquivo não encontrado: ${CONFIG_FILE}"
  exit 1
fi

echo "→ Calculando PAT Base64 para o proxy header..."
PAT_BASE64=$(echo -n ":${AZURE_DEVOPS_PAT}" | base64)

echo "→ Processando template de configuração..."
CONFIG_CONTENT=$(sed \
  -e "s|<BASE64_HARDCODED_DO_PAT>|${PAT_BASE64}|g" \
  -e "s|\${GITHUB_USER}|${GITHUB_USER}|g" \
  "${CONFIG_FILE}")

echo "→ Aplicando patch no ConfigMap ${RHDH_CONFIGMAP_APPCONFIG}..."
oc patch configmap "${RHDH_CONFIGMAP_APPCONFIG}" -n "${OCP_NAMESPACE}" \
  --type=merge \
  -p "{\"data\":{\"app-config.azure.yaml\":$(echo "${CONFIG_CONTENT}" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"

echo "✓ ConfigMap atualizado com sucesso."
echo ""
echo "Execute o próximo passo:"
echo "  bash scripts/03-restart-rhdh.sh"
