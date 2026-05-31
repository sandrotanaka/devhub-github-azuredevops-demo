# 01 — Pré-requisitos

---

## OpenShift

- Cluster OpenShift 4.12+ acessível
- `oc` CLI instalado e autenticado:

```bash
oc whoami
oc version
```

---

## Arquivo .env

Configure o `.env` antes de qualquer comando:

```bash
cp .env.example .env
# Edite com seus valores reais
```

Sempre que abrir um novo terminal:

```bash
set -a && source .env && set +a
```

> ⚠️ Não use `export $(cat .env | xargs)` — falha com caracteres especiais como `=` e `+` presentes em PATs e base64.

Confirme:
```bash
echo "Namespace         : ${OCP_NAMESPACE}"
echo "ConfigMap config  : ${RHDH_CONFIGMAP_APPCONFIG}"
echo "ConfigMap plugins : ${RHDH_CONFIGMAP_PLUGINS}"
echo "Secret            : ${RHDH_SECRET}"
echo "ADO Org           : ${AZURE_DEVOPS_ORG}"
echo "ADO Project       : ${AZURE_DEVOPS_PROJECT}"
```

---

## GitHub

### Token de acesso (integração RHDH)

O RHDH precisa de um token GitHub para ler arquivos de repositórios (templates, `catalog-info.yaml`).

1. Acesse `https://github.com/settings/tokens`
2. **Generate new token (classic)**
3. Escopos: `repo` (privado) ou `public_repo` (somente públicos)
4. Salve em `.env` como `GITHUB_TOKEN`

### OAuth App (autenticação de usuários)

O RHDH usa GitHub OAuth para login. Crie após obter a URL da Route do RHDH:

1. Acesse `https://github.com/settings/developers → OAuth Apps → New OAuth App`
2. Preencha:
   - **Homepage URL:** `https://<HOST_DA_ROUTE>`
   - **Authorization callback URL:** `https://<HOST_DA_ROUTE>/api/auth/github/handler/frame`
3. Clique em **Register application**
4. Clique em **Generate a new client secret**
5. Salve `Client ID` em `GITHUB_CLIENT_ID` e o secret em `GITHUB_CLIENT_SECRET`

> ⚠️ O callback URL deve ser exato — sem barra no final, sem espaços. Um URL incorreto resulta em `redirect_uri is not associated with this application`.

---

## Azure DevOps

### PAT (Personal Access Token)

1. Acesse **User Settings → Personal Access Tokens → New Token**
2. Escopos obrigatórios:

   | Escopo | Permissão |
   |---|---|
   | Build | Read & Execute |
   | Code | Read |
   | Service Connections | Read & Query |
   | Project and Team | Read |

3. Salve em `.env` como `AZURE_DEVOPS_PAT`

### AZURE_DEVOPS_PAT_BASE64

O proxy do RHDH usa autenticação Basic com o PAT em base64 no formato `:PAT`. Gere e salve no `.env`:

```bash
echo -n ":${AZURE_DEVOPS_PAT}" | base64 | tr -d '\n'
```

Salve como `AZURE_DEVOPS_PAT_BASE64` no `.env` e adicione ao Secret do cluster:

```bash
PAT_BASE64=$(echo -n ":${AZURE_DEVOPS_PAT}" | base64 | tr -d '\n')

oc patch secret ${RHDH_SECRET} -n ${OCP_NAMESPACE} \
  --type=merge \
  -p "{\"stringData\": {\"AZURE_DEVOPS_PAT_BASE64\": \"${PAT_BASE64}\"}}"
```

> ⚠️ Sem essa variável, o proxy `/azure-devops` retorna 401 e os steps de criação de pipeline no template falham silenciosamente.

### Service Connection GitHub → Azure DevOps

Necessária para que pipelines ADO acessem repositórios GitHub:

1. Acesse `Project Settings → Service connections → New service connection`
2. Selecione **GitHub**
3. Autentique via OAuth ou PAT do GitHub (`repo, user, admin:repo_hook`)
4. Marque **Grant access permission to all pipelines**
5. Clique em **Verify and save**

Obtenha o ID da connection:

```bash
curl -sk -u ":${AZURE_DEVOPS_PAT}" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/serviceendpoint/endpoints?type=GitHub&api-version=7.1" \
  | python3 -c "
import sys, json
for c in json.load(sys.stdin).get('value', []):
    print(f'ID:   {c[\"id\"]}')
    print(f'Nome: {c[\"name\"]}')
"
```

Salve em `.env` como `AZURE_GITHUB_SERVICE_CONNECTION_ID` e substitua em `templates/quarkus-github-ado/template.yaml`.
