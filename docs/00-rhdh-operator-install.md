# 00 — Instalação do RHDH via Operador

Este guia cobre a criação de uma instância do Red Hat Developer Hub do zero, partindo de um cluster OpenShift com o operador RHDH já instalado via OperatorHub.

---

## Pré-requisitos

- Operador **Red Hat Developer Hub** instalado via OperatorHub
- Acesso de administrador ao namespace de destino
- `oc` CLI autenticado no cluster

Verificar se o operador está instalado:

```bash
oc get csv -A | grep developer-hub
```

Resultado esperado:
```
rhdh          red-hat-developer-hub.v1.9.x   Red Hat Developer Hub   1.9.x   Succeeded
```

---

## Passo 1 — Criar o namespace

```bash
oc new-project devhub-azure-demo
# ou
oc create namespace devhub-azure-demo
```

---

## Passo 2 — Criar o Secret de variáveis de ambiente

O operador injeta as variáveis deste secret no pod do RHDH. Crie-o antes da instância:

```bash
# Carregar variáveis
set -a && source .env && set +a

# Gerar Base64
B64_ORG=$(echo -n "${AZURE_DEVOPS_ORG}" | base64 | tr -d '\n')
B64_PROJECT=$(echo -n "${AZURE_DEVOPS_PROJECT}" | base64 | tr -d '\n')
B64_PAT=$(echo -n "${AZURE_DEVOPS_PAT}" | base64 | tr -d '\n')
B64_GITHUB_USER=$(echo -n "${GITHUB_USER}" | base64 | tr -d '\n')
B64_GITHUB_TOKEN=$(echo -n "${GITHUB_TOKEN}" | base64 | tr -d '\n')

# Criar o secret
oc apply -n devhub-azure-demo -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: rhdh-env
  namespace: devhub-azure-demo
type: Opaque
data:
  AZURE_DEVOPS_ORG: ${B64_ORG}
  AZURE_DEVOPS_PROJECT: ${B64_PROJECT}
  AZURE_DEVOPS_PAT: ${B64_PAT}
  GITHUB_USER: ${B64_GITHUB_USER}
  GITHUB_TOKEN: ${B64_GITHUB_TOKEN}
YAML
```

---

## Passo 3 — Criar o ConfigMap de app-config

```bash
# Calcular PAT Base64 para o proxy header
PAT_BASE64=$(echo -n ":${AZURE_DEVOPS_PAT}" | base64 | tr -d '\n')

# Processar o template substituindo o placeholder
CONFIG_CONTENT=$(sed "s|<BASE64_HARDCODED_DO_PAT>|${PAT_BASE64}|g" config/app-config.azure.yaml)

# Criar o ConfigMap
oc create configmap rhdh-app-config \
  -n devhub-azure-demo \
  --from-literal="app-config.azure.yaml=${CONFIG_CONTENT}"
```

Verificar:

```bash
oc get configmap rhdh-app-config -n devhub-azure-demo -o jsonpath='{.data}' | python3 -m json.tool | grep "app-config"
```

---

## Passo 4 — Criar o ConfigMap de dynamic-plugins

```bash
oc create configmap rhdh-dynamic-plugins \
  -n devhub-azure-demo \
  --from-literal="dynamic-plugins.yaml=$(cat << 'YAML'
includes:
- dynamic-plugins.default.yaml
plugins:
- disabled: false
  package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops:bs_1.45.3__0.23.0
- disabled: false
  package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops-backend:bs_1.45.3__0.23.0
YAML
)"
```

> ⚠️ RHDH 1.9: plugins Azure DevOps são distribuídos via OCI (`ghcr.io`). Paths locais `./dynamic-plugins/dist/backstage-plugin-azure-devops*` não existem nesta versão. Veja `config/dynamic-plugins.yaml`.

---

## Passo 5 — Criar a instância do Backstage (CR)

```bash
oc apply -n devhub-azure-demo -f - <<'YAML'
apiVersion: rhdh.redhat.com/v1alpha3
kind: Backstage
metadata:
  name: developer-hub
  namespace: devhub-azure-demo
spec:
  application:
    appConfig:
      configMaps:
        - name: rhdh-app-config
    dynamicPluginsConfigMapName: rhdh-dynamic-plugins
    extraEnvs:
      secrets:
        - name: rhdh-env
    replicas: 1
    route:
      enabled: true
YAML
```

Aguardar a instância ficar pronta:

```bash
oc get backstage developer-hub -n devhub-azure-demo -w
```

Resultado esperado:
```
NAME            READY
developer-hub   True
```

---

## Passo 6 — Verificar os recursos criados

O operador cria automaticamente os seguintes recursos:

```bash
oc get deployment,configmap,secret -n devhub-azure-demo | grep -i backstage
```

Recursos esperados:

| Recurso | Nome |
|---|---|
| Deployment | `backstage-developer-hub` |
| ConfigMap (operador) | `backstage-appconfig-developer-hub` |
| ConfigMap (operador) | `backstage-dynamic-plugins-developer-hub` |
| ConfigMap (operador) | `backstage-files-developer-hub` |

> Não edite os ConfigMaps prefixados com `backstage-` — são gerenciados internamente pelo operador.

---

## Passo 7 — Verificar plugins Azure carregados

```bash
# Init container — instalação
oc logs -n devhub-azure-demo deployment/backstage-developer-hub \
  -c install-dynamic-plugins | grep -i azure

# Backend — inicialização
oc logs -n devhub-azure-demo deployment/backstage-developer-hub \
  -c backstage-backend | grep -i azure
```

Resultado esperado no backend:
```
backstage info loaded dynamic backend plugin '@backstage-community/plugin-azure-devops-backend-dynamic'
proxy info [HPM] Proxy created: /azure-devops  -> https://dev.azure.com
scalprum info Loaded dynamic frontend plugin '@backstage-community/plugin-azure-devops-dynamic'
backstage info Plugin initialization in progress, newly initialized: ... 'azure-devops' ...
```

---

## Passo 8 — Acessar o RHDH

```bash
oc get route -n devhub-azure-demo -o jsonpath='{.items[0].spec.host}'
```

Acesse `https://<host-retornado>` no browser.

---

## Próximos passos

Com a instância funcionando, siga:

- `docs/03-azure-devops.md` — criar projeto ADO, PAT e Service Connection GitHub
- `docs/04-templates.md` — registrar o template `quarkus-github-ado` no catálogo
