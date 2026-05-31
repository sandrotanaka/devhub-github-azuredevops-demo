#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# 03-restart-rhdh.sh
# Reinicia o deployment do RHDH e aguarda o rollout
# Uso: source .env && bash scripts/03-restart-rhdh.sh
# =============================================================

: "${OCP_NAMESPACE:?Variável OCP_NAMESPACE não definida. Execute: source .env}"
: "${RHDH_DEPLOYMENT:?Variável RHDH_DEPLOYMENT não definida. Execute: source .env}"

echo "→ Verificando login no OpenShift..."
oc whoami > /dev/null || { echo "ERRO: não autenticado. Execute 'oc login' primeiro."; exit 1; }

echo "→ Reiniciando deployment/${RHDH_DEPLOYMENT}..."
oc rollout restart deployment/"${RHDH_DEPLOYMENT}" -n "${OCP_NAMESPACE}"

echo "→ Aguardando rollout completar..."
oc rollout status deployment/"${RHDH_DEPLOYMENT}" -n "${OCP_NAMESPACE}"

echo ""
echo "✓ RHDH reiniciado com sucesso."
echo ""
echo "Para verificar os plugins carregados, acesse:"
RHDH_HOST=$(oc get route -n "${OCP_NAMESPACE}" -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "<RHDH_HOST>")
echo "  https://${RHDH_HOST}/api/dynamic-plugins-info/loaded-plugins"
