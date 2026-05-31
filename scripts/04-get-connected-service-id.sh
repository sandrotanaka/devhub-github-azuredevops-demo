#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# 04-get-connected-service-id.sh
# Busca o ID da Service Connection GitHub no Azure DevOps
# Uso: source .env && bash scripts/04-get-connected-service-id.sh
# =============================================================

: "${AZURE_DEVOPS_ORG:?Variável AZURE_DEVOPS_ORG não definida. Execute: source .env}"
: "${AZURE_DEVOPS_PROJECT:?Variável AZURE_DEVOPS_PROJECT não definida. Execute: source .env}"
: "${AZURE_DEVOPS_PAT:?Variável AZURE_DEVOPS_PAT não definida. Execute: source .env}"

echo "→ Buscando Service Connections do tipo GitHub..."
echo ""

RESULT=$(curl -sk -u ":${AZURE_DEVOPS_PAT}" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/serviceendpoint/endpoints?type=GitHub&api-version=7.1")

echo "${RESULT}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
conns = data.get('value', [])
if not conns:
    print('Nenhuma Service Connection GitHub encontrada.')
    print('Crie em: Project Settings → Service connections → New → GitHub')
    sys.exit(1)
for c in conns:
    print(f'  ID:   {c[\"id\"]}')
    print(f'  Nome: {c[\"name\"]}')
    print()
"

echo "Copie o ID desejado e adicione ao .env:"
echo "  AZURE_GITHUB_SERVICE_CONNECTION_ID=<ID>"
