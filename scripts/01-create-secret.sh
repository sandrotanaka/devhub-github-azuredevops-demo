#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# 01-create-secret.sh
# Aplica patch no secret do RHDH com as credenciais ADO
# Uso: source .env && bash scripts/01-create-secret.sh
# =============================================================

: "${AZURE_DEVOPS_ORG:?Variável AZURE_DEVOPS_ORG não definida. Execute: source .env}"
: "${AZURE_DEVOPS_PROJECT:?Variável AZURE_DEVOPS_PROJECT não definida. Execute: source .env}"
: "${AZURE_DEVOPS_PAT:?Variável AZURE_DEVOPS_PAT não definida. Execute: source .env}"
: "${OCP_NAMESPACE:?Variável OCP_NAMESPACE não definida. Execute: source .env}"
: "${RHDH_SECRET:?Variável RHDH_SECRET não definida. Execute: source .env}"

echo "→ Verificando login no OpenShift..."
oc whoami > /dev/null || { echo "ERRO: não autenticado. Execute 'oc login' primeiro."; exit 1; }

echo "→ Gerando valores Base64..."
B64_ORG=$(echo -n "${AZURE_DEVOPS_ORG}" | base64)
B64_PROJECT=$(echo -n "${AZURE_DEVOPS_PROJECT}" | base64)
B64_PAT=$(echo -n "${AZURE_DEVOPS_PAT}" | base64)

echo ""
echo "====================================================="
echo "PAT no formato ':PAT' para uso em Authorization Basic:"
echo -n ":${AZURE_DEVOPS_PAT}" | base64
echo "====================================================="
echo "Copie esse valor e substitua <BASE64_HARDCODED_DO_PAT>"
echo "em config/app-config.azure.yaml e templates/quarkus-github-ado/template.yaml"
echo ""

echo "→ Aplicando patch no secret ${RHDH_SECRET}..."
oc patch secret "${RHDH_SECRET}" -n "${OCP_NAMESPACE}" \
  --type='json' \
  -p="[
    {\"op\":\"add\",\"path\":\"/data/AZURE_DEVOPS_ORG\",     \"value\":\"${B64_ORG}\"},
    {\"op\":\"add\",\"path\":\"/data/AZURE_DEVOPS_PROJECT\", \"value\":\"${B64_PROJECT}\"},
    {\"op\":\"add\",\"path\":\"/data/AZURE_DEVOPS_PAT\",     \"value\":\"${B64_PAT}\"}
  ]"

echo "✓ Secret atualizado com sucesso."
