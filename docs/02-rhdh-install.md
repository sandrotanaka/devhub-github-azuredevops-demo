# 02 — Instalação e configuração do RHDH

---

## Antes de começar — identifique os recursos no seu cluster

```bash
# Localizar o namespace
oc get deployment --all-namespaces | grep -i backstage

# Listar recursos no namespace encontrado
NAMESPACE=<seu-namespace>
oc get configmap -n $NAMESPACE | grep -i developer-hub
oc get secret -n $NAMESPACE | grep -i developer-hub
```

### Recursos descobertos no ambiente de referência (RHDH 1.9, instalação via Operador)

| Recurso | Tipo | Nome |
|---|---|---|
| Namespace | — | `${OCP_NAMESPACE}` |
| Deployment | Deployment | `backstage-developer-hub` |
| app-config | ConfigMap | `${RHDH_CONFIGMAP_APPCONFIG}` |
| dynamic-plugins | ConfigMap | `${RHDH_CONFIGMAP_PLUGINS}` |
| Variáveis de ambiente | Secret | `${RHDH_SECRET}` |

> O operador também cria `backstage-appconfig-developer-hub`, `backstage-dynamic-plugins-developer-hub` e `backstage-files-developer-hub`. **Não edite esses recursos** — são gerenciados internamente pelo operador. Use apenas os prefixados com o nome da sua instância (`${RHDH_SECRET/env/*}`).

---

## Passo 1 — Secret com variáveis de ambiente

```bash
# Gerar valores Base64
B64_ORG=$(echo -n "${AZURE_DEVOPS_ORG}" | base64)
B64_PROJECT=$(echo -n "${AZURE_DEVOPS_PROJECT}" | base64)
B64_PAT=$(echo -n "${AZURE_DEVOPS_PAT}" | base64)

# Aplicar patch no secret
oc patch secret ${RHDH_SECRET} -n ${OCP_NAMESPACE} \
  --type='json' \
  -p="[
    {\"op\":\"add\",\"path\":\"/data/AZURE_DEVOPS_ORG\",     \"value\":\"${B64_ORG}\"},
    {\"op\":\"add\",\"path\":\"/data/AZURE_DEVOPS_PROJECT\", \"value\":\"${B64_PROJECT}\"},
    {\"op\":\"add\",\"path\":\"/data/AZURE_DEVOPS_PAT\",     \"value\":\"${B64_PAT}\"}
  ]"
```

> O PAT também precisa ser inserido em Base64 no formato `:PAT` nos headers hardcoded. Calcule e guarde o valor:
> ```bash
> echo -n ":${AZURE_DEVOPS_PAT}" | base64 | tr -d '\n'
> ```
> Substitua `<BASE64_HARDCODED_DO_PAT>` em `config/app-config.azure.yaml` e `templates/quarkus-github-ado/template.yaml`.

---

## Passo 2 — app-config

Adicionar a chave `app-config.azure.yaml` ao ConfigMap `${RHDH_CONFIGMAP_APPCONFIG}`:

```bash
# Calcular PAT Base64 para o proxy header
PAT_BASE64=$(echo -n ":${AZURE_DEVOPS_PAT}" | base64 | tr -d '\n')

# Ler o template e substituir o placeholder
CONFIG_CONTENT=$(sed "s|<BASE64_HARDCODED_DO_PAT>|${PAT_BASE64}|g" config/app-config.azure.yaml)

# Aplicar patch
oc patch configmap ${RHDH_CONFIGMAP_APPCONFIG} -n ${OCP_NAMESPACE} \
  --type=merge \
  -p "{\"data\":{\"app-config.azure.yaml\":$(echo "${CONFIG_CONTENT}" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"
```

O arquivo `config/app-config.azure.yaml` configura:

| Seção | Finalidade |
|---|---|
| `integrations.azure` | Autenticação para leitura de repositórios ADO |
| `azureDevOps` | Plugin backend da aba CI |
| `proxy.endpoints./azure-devops` | Proxy para chamadas à API ADO via templates |
| `catalog.locations` | URL do `all-templates.yaml` neste repositório GitHub |
| `catalog.providers.azureDevOps` | Discovery de `catalog-info.yaml` nos repos ADO |

> ⚠️ Variáveis `${VAR}` **não são expandidas** dentro de `proxy.endpoints.headers`. O valor Base64 do PAT deve ser inserido literalmente nesse campo.

---

## Passo 3 — Dynamic Plugins (RHDH 1.9)

> ⚠️ **RHDH 1.9 — Breaking change:** Plugins Azure DevOps são community plugins migrados para OCI (`ghcr.io`). Paths locais `./dynamic-plugins/dist/backstage-plugin-azure-devops*` **não existem** nesta versão.
>
> Referência: [Dynamic Plugins Reference 1.9](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.9/html-single/dynamic_plugins_reference/index)

Adicionar os dois plugins Azure ao ConfigMap existente (preservando todos os outros plugins):

```bash
# Verificar plugins Azure já carregados
oc get configmap ${RHDH_CONFIGMAP_PLUGINS} -n ${OCP_NAMESPACE} \
  -o jsonpath='{.data.dynamic-plugins\.yaml}' | grep -i azure
```

Se não aparecerem, adicionar ao final do bloco `plugins:` via `oc patch`:

```bash
oc patch configmap ${RHDH_CONFIGMAP_PLUGINS} -n ${OCP_NAMESPACE} \
  --type=merge \
  -p '{"data":{"dynamic-plugins.yaml":"<CONTEUDO_COMPLETO_COM_PLUGINS_AZURE>"}}'
```

> O conteúdo completo deve preservar todos os plugins existentes. Veja o comando completo em `troubleshooting/errors.md`.

Plugins Azure DevOps corretos para RHDH 1.9:

```yaml
- disabled: false
  package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops:bs_1.45.3__0.23.0
- disabled: false
  package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops-backend:bs_1.45.3__0.23.0
```

Verificar instalação no log do init container:

```bash
oc logs -n ${OCP_NAMESPACE} deployment/backstage-developer-hub -c install-dynamic-plugins | grep -i azure
```

Resultado esperado:
```
======= Skipping download of already installed dynamic plugin ...backstage-community-plugin-azure-devops... (already_installed)
======= Skipping download of already installed dynamic plugin ...backstage-community-plugin-azure-devops-backend... (already_installed)
```

---

## Passo 4 — Reiniciar o RHDH

```bash
oc rollout restart deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
oc rollout status deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
```

Verificar plugins carregados no log do backend:

```bash
oc logs -n ${OCP_NAMESPACE} deployment/backstage-developer-hub -c backstage-backend | grep -i azure
```

Resultado esperado:
```
backstage info loaded dynamic backend plugin '@backstage-community/plugin-azure-devops-backend-dynamic'
proxy info [HPM] Proxy created: /azure-devops  -> https://dev.azure.com
scalprum info Loaded dynamic frontend plugin '@backstage-community/plugin-azure-devops-dynamic'
backstage info Plugin initialization in progress, newly initialized: ... 'azure-devops' ...
```
