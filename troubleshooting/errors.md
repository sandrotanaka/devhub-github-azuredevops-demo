# Troubleshooting — Erros comuns

---

## Tabela de erros

| Erro | Causa | Solução |
|---|---|---|
| `No pool was specified` | `azure-pipelines.yml` sem bloco `pool` | Adicionar `pool: vmImage: 'ubuntu-latest'` |
| `401 Unauthorized` no proxy | Base64 do PAT incorreto ou variável não expandida | Usar valor Base64 hardcoded: `echo -n ":<PAT>" \| base64 \| tr -d '\n'` |
| Pipeline não aparece na aba CI | Anotações erradas no `catalog-info.yaml` | Usar `dev.azure.com/project` + `dev.azure.com/build-definition: adoOrg.appName` |
| `No repository found` na aba CI | Uso de `project-repo` para repo no GitHub | Remover `project-repo`; usar só `project` + `build-definition` |
| Template não aparece no RHDH | `all-templates.yaml` não carregado ou URL errada | Verificar location no app-config e forçar refresh no catálogo |
| `connectedServiceId` inválido | ID de outro projeto ou ambiente | Buscar via API (ver seção abaixo) |
| `npm error ENOENT package.json` no init container | Path `./dynamic-plugins/dist/backstage-plugin-azure-devops*` não existe no RHDH 1.9 | Usar paths OCI `ghcr.io` (ver Passo 3 em `docs/02-rhdh-install.md`) |

---

## RHDH 1.9 — Plugins Azure DevOps via OCI

No RHDH 1.9, os plugins Azure DevOps são community plugins distribuídos via OCI no `ghcr.io`.
Paths locais `./dynamic-plugins/dist/backstage-plugin-azure-devops*` **não existem** nesta versão.

Paths corretos validados:

```yaml
- disabled: false
  package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops:bs_1.45.3__0.23.0
- disabled: false
  package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops-backend:bs_1.45.3__0.23.0
```

---

## Obter ID da Service Connection GitHub

```bash
curl -sk -u ":${AZURE_DEVOPS_PAT}" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/serviceendpoint/endpoints?type=GitHub&api-version=7.1" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data.get('value', []):
    print(f'ID:   {c[\"id\"]}')
    print(f'Nome: {c[\"name\"]}')
    print()
"
```

---

## Verificar plugins carregados

```bash
# Init container — instalação dos plugins
oc logs -n tssc-dh deployment/backstage-developer-hub -c install-dynamic-plugins | grep -i azure

# Backend — plugins inicializados
oc logs -n tssc-dh deployment/backstage-developer-hub -c backstage-backend | grep -i azure
```

---

## Verificar variáveis expandidas no pod

```bash
oc exec -n tssc-dh deployment/backstage-developer-hub \
  -c backstage-backend -- env | grep AZURE
```

---

## Forçar refresh do catálogo

No RHDH, acesse:
```
Settings → Catalog → Locations → <location> → Refresh
```

Ou via API (requer token de sessão do RHDH):

```bash
RHDH_HOST=$(oc get route -n tssc-dh -o jsonpath='{.items[0].spec.host}')
curl -sk -X POST "https://${RHDH_HOST}/api/catalog/locations/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"url\",\"target\":\"https://raw.githubusercontent.com/${GITHUB_USER}/devhub-github-azuredevops-demo/main/templates/all-templates.yaml\"}"
```
