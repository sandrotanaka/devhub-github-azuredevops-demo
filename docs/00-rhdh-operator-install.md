# 00 — Instalação do RHDH via Operador

Este guia cobre a instalação do Red Hat Developer Hub do zero, partindo de um cluster OpenShift com o operador RHDH já disponível no OperatorHub.

---

## Pré-requisitos

- Acesso de administrador ao cluster OpenShift 4.12+
- `oc` CLI instalado e autenticado
- Arquivo `.env` preenchido (copie de `.env.example`)

```bash
oc whoami
oc version
```

---

## Passo 1 — Verificar o operador

```bash
oc get csv --all-namespaces | grep rhdh
```

Resultado esperado:
```
rhdh-operator   rhdh-operator.v1.9.4   Red Hat Developer Hub Operator   1.9.4   Succeeded
```

Se não aparecer, instale via console OpenShift:
> **Operators → OperatorHub → buscar "Red Hat Developer Hub" → Install**

---

## Passo 2 — Criar o namespace

```bash
set -a && source .env && set +a

oc new-project ${OCP_NAMESPACE}
```

---

## Passo 3 — Criar o Secret de variáveis de ambiente

> ⚠️ Use `oc create secret generic` — ele faz o base64 automaticamente. Não gere base64 manualmente.

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

Verificar:
```bash
oc get secret ${RHDH_SECRET} -n ${OCP_NAMESPACE} -o jsonpath='{.data}' \
  | python3 -c "import sys,json,base64; [print(k,'=',base64.b64decode(v).decode()[:4]+'***') for k,v in json.load(sys.stdin).items()]"
```

---

## Passo 4 — Criar o ConfigMap de app-config

```bash
oc create configmap ${RHDH_CONFIGMAP_APPCONFIG} \
  --from-file=app-config.yaml=config/app-config.azure.yaml \
  -n ${OCP_NAMESPACE}
```

---

## Passo 5 — Criar o ConfigMap de dynamic-plugins

```bash
oc create configmap ${RHDH_CONFIGMAP_PLUGINS} \
  --from-file=dynamic-plugins.yaml=config/dynamic-plugins.yaml \
  -n ${OCP_NAMESPACE}
```

---

## Passo 6 — Criar a instância Backstage (CR)

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

> ⚠️ **Não use `<<'YAML'`** (com aspas simples) — impede a expansão das variáveis `${...}`.

Aguardar a instância ficar pronta:
```bash
oc get backstage developer-hub -n ${OCP_NAMESPACE} -w
```

---

## Passo 7 — Obter a URL do RHDH

```bash
oc get route -n ${OCP_NAMESPACE}
```

Anote o `HOST/PORT` — será usado para configurar o OAuth App do GitHub.

---

## Passo 8 — Configurar o GitHub OAuth App

O RHDH usa GitHub como provedor de autenticação. Crie o OAuth App em:

> **https://github.com/settings/developers → OAuth Apps → New OAuth App**

| Campo | Valor |
|---|---|
| Application name | `rhdh-demo` |
| Homepage URL | `https://<HOST_DA_ROUTE>` |
| Authorization callback URL | `https://<HOST_DA_ROUTE>/api/auth/github/handler/frame` |

Clique em **Register application** e depois em **Generate a new client secret**.

Atualize o Secret com as credenciais geradas:

```bash
oc patch secret ${RHDH_SECRET} -n ${OCP_NAMESPACE} \
  --type=merge \
  -p "{\"stringData\": {\"GITHUB_CLIENT_ID\": \"<CLIENT_ID>\", \"GITHUB_CLIENT_SECRET\": \"<CLIENT_SECRET>\"}}"
```

Reinicie o pod:
```bash
oc rollout restart deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
oc rollout status deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
```

---

## Passo 9 — Verificar

```bash
# Pods rodando
oc get pods -n ${OCP_NAMESPACE} | grep backstage

# Plugins Azure carregados
oc logs deployment/backstage-developer-hub -n ${OCP_NAMESPACE} \
  -c backstage-backend | grep -i azure
```

Acesse `https://<HOST_DA_ROUTE>` — o login deve redirecionar para o GitHub.

---

## Próximos passos

- `docs/01-prerequisites.md` — tokens e pré-requisitos detalhados
- `docs/03-azure-devops.md` — Service Connection GitHub no ADO
- `docs/04-templates.md` — registrar templates no catálogo
