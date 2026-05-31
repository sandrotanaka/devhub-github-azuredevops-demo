# 02 — Configuração de instância existente

Use este guia se o operador RHDH já está instalado e você quer configurar uma nova instância do zero.

---

## Identificar recursos no cluster

```bash
# Verificar operador
oc get csv --all-namespaces | grep rhdh

# Listar namespaces com instâncias existentes
oc get backstage --all-namespaces
```

---

## Passo 1 — Carregar variáveis

```bash
set -a && source .env && set +a

echo "Namespace : ${OCP_NAMESPACE}"
echo "Secret    : ${RHDH_SECRET}"
```

---

## Passo 2 — Criar o namespace

```bash
oc new-project ${OCP_NAMESPACE}
```

---

## Passo 3 — Criar o Secret

> ⚠️ Use `oc create secret generic` — faz o base64 automaticamente.

```bash
PAT_BASE64=$(echo -n ":${AZURE_DEVOPS_PAT}" | base64 | tr -d '\n')

oc create secret generic ${RHDH_SECRET} \
  --from-literal=AZURE_DEVOPS_ORG=${AZURE_DEVOPS_ORG} \
  --from-literal=AZURE_DEVOPS_PROJECT=${AZURE_DEVOPS_PROJECT} \
  --from-literal=AZURE_DEVOPS_PAT=${AZURE_DEVOPS_PAT} \
  --from-literal=AZURE_DEVOPS_PAT_BASE64=${PAT_BASE64} \
  --from-literal=GITHUB_TOKEN=${GITHUB_TOKEN} \
  --from-literal=GITHUB_USER=${GITHUB_USER} \
  --from-literal=GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID} \
  --from-literal=GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET} \
  -n ${OCP_NAMESPACE}
```

---

## Passo 4 — Criar os ConfigMaps

```bash
oc create configmap ${RHDH_CONFIGMAP_APPCONFIG} \
  --from-file=app-config.yaml=config/app-config.azure.yaml \
  -n ${OCP_NAMESPACE}

oc create configmap ${RHDH_CONFIGMAP_PLUGINS} \
  --from-file=dynamic-plugins.yaml=config/dynamic-plugins.yaml \
  -n ${OCP_NAMESPACE}
```

Para atualizar um ConfigMap existente:

```bash
oc create configmap ${RHDH_CONFIGMAP_APPCONFIG} \
  --from-file=app-config.yaml=config/app-config.azure.yaml \
  -n ${OCP_NAMESPACE} \
  --dry-run=client -o yaml | oc apply -f -
```

---

## Passo 5 — Criar o CR Backstage

> ⚠️ Use `<<YAML` sem aspas para expandir `${...}`.

```bash
oc apply -n ${OCP_NAMESPACE} -f - <<YAML
apiVersion: rhdh.redhat.com/v1alpha3
kind: Backstage
metadata:
  name: developer-hub
  namespace: ${OCP_NAMESPACE}
spec:
  application:
    appConfig:
      configMaps:
        - name: ${RHDH_CONFIGMAP_APPCONFIG}
    dynamicPluginsConfigMapName: ${RHDH_CONFIGMAP_PLUGINS}
    extraEnvs:
      secrets:
        - name: ${RHDH_SECRET}
    replicas: 1
    route:
      enabled: true
YAML
```

Verificar status:

```bash
oc get backstage developer-hub -n ${OCP_NAMESPACE} \
  -o jsonpath='{.status.conditions[*].message}'
```

---

## Passo 6 — Configurar GitHub OAuth App

Obtenha a URL da Route:

```bash
oc get route -n ${OCP_NAMESPACE}
```

Crie o OAuth App em `https://github.com/settings/developers`:
- **Authorization callback URL:** `https://<HOST>/api/auth/github/handler/frame`

Atualize o Secret:

```bash
oc patch secret ${RHDH_SECRET} -n ${OCP_NAMESPACE} \
  --type=merge \
  -p "{\"stringData\": {
    \"GITHUB_CLIENT_ID\": \"${GITHUB_CLIENT_ID}\",
    \"GITHUB_CLIENT_SECRET\": \"${GITHUB_CLIENT_SECRET}\"
  }}"
```

---

## Passo 7 — Reiniciar e verificar

```bash
oc rollout restart deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
oc rollout status deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
```

Verificar variáveis disponíveis no pod:

```bash
oc exec deployment/backstage-developer-hub -n ${OCP_NAMESPACE} -- env | grep -E "AZURE|GITHUB"
```

Verificar plugins Azure carregados:

```bash
oc logs deployment/backstage-developer-hub -n ${OCP_NAMESPACE} \
  -c backstage-backend | grep -i azure
```

---

## Recursos criados pelo operador

O operador cria automaticamente os seguintes recursos adicionais — **não edite**:

| Recurso | Nome |
|---|---|
| ConfigMap | `backstage-appconfig-developer-hub` |
| ConfigMap | `backstage-dynamic-plugins-developer-hub` |
| ConfigMap | `backstage-files-developer-hub` |
| Secret | `backstage-psql-secret-developer-hub` |

---

## Troubleshooting

**Secret not found:**
```
failed to get external config from <RHDH_SECRET>: Secret "<RHDH_SECRET>" not found
```
→ O Secret foi criado em namespace diferente do CR. Verifique `${OCP_NAMESPACE}`.

**auth provider missing clientId:**
```
Missing required config value at 'auth.providers.github.production.clientId'
```
→ `GITHUB_CLIENT_ID` não está no Secret ou OAuth App não foi criado.

**Proxy retorna 401 ao criar pipeline:**
→ `AZURE_DEVOPS_PAT_BASE64` não está no Secret. Veja Passo 3.
