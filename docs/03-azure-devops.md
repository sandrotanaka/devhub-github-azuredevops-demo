# 03 — Integração com Azure DevOps

---

## Passo 1 — Criar o projeto ADO

1. Acesse `https://dev.azure.com/<SUA_ORG>`
2. Clique em **New project**
3. Preencha:
   - **Project name:** valor de `${AZURE_DEVOPS_PROJECT}`
   - **Visibility:** Private
4. Clique em **Create**

---

## Passo 2 — Criar o PAT

1. Acesse **User Settings → Personal Access Tokens → New Token**
2. Escopos obrigatórios:

   | Escopo | Permissão |
   |---|---|
   | Build | Read & Execute |
   | Code | Read |
   | **Service Connections** | **Read & Query** |
   | Project and Team | Read |

   > ⚠️ O escopo **Service Connections** é obrigatório. Sem ele, o passo de obtenção do `connectedServiceId` retorna 401.

3. Copie o token e salve em `.env` como `AZURE_DEVOPS_PAT`

---

## Passo 3 — Criar a Service Connection GitHub

1. Acesse `Project Settings → Service connections → New service connection`
2. Selecione **GitHub → Next**
3. Autentique via OAuth ou PAT do GitHub (escopos: `repo, user, admin:repo_hook`)
4. Marque **Grant access permission to all pipelines**
5. Clique em **Verify and save**

---

## Passo 4 — Obter o ID da Service Connection

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

Salve o ID em `.env` como `AZURE_GITHUB_SERVICE_CONNECTION_ID` e substitua em `templates/quarkus-github-ado/template.yaml`:

```yaml
properties:
  connectedServiceId: "<ID_RETORNADO>"
```

---

## Convenção de nomes de pipeline

Ao criar uma pipeline via API apontando para um repositório GitHub, o Azure DevOps nomeia automaticamente como:

```
<adoOrg>.<appName>
```

Exemplo: org `sandrotanaka`, app `minha-api` → pipeline `sandrotanaka.minha-api`.

Por isso o `catalog-info.yaml` usa:

```yaml
dev.azure.com/build-definition: ${{ values.adoOrg }}.${{ values.appName }}
```

---

## Verificar integração

```bash
# Listar pipelines existentes
curl -sk -u ":${AZURE_DEVOPS_PAT}" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/build/definitions?api-version=7.1" \
  | python3 -c "
import sys, json
for p in json.load(sys.stdin).get('value', []):
    print(p['id'], p['name'])
"
```

## Criar pipeline manualmente (fallback)

Se o scaffold falhar no step `create-pipeline`, crie manualmente:

```bash
curl -s -u :${AZURE_DEVOPS_PAT} \
  -X POST \
  -H "Content-Type: application/json" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/build/definitions?api-version=7.1" \
  -d "{
    \"name\": \"${AZURE_DEVOPS_ORG}.<APP_NAME>\",
    \"process\": {\"type\": 2, \"yamlFilename\": \"/azure-pipelines.yml\"},
    \"queue\": {\"pool\": {\"name\": \"Azure Pipelines\"}},
    \"repository\": {
      \"id\": \"${GITHUB_USER}/<APP_NAME>\",
      \"name\": \"${GITHUB_USER}/<APP_NAME>\",
      \"url\": \"https://github.com/${GITHUB_USER}/<APP_NAME>\",
      \"type\": \"GitHub\",
      \"defaultBranch\": \"main\",
      \"properties\": {
        \"connectedServiceId\": \"${AZURE_GITHUB_SERVICE_CONNECTION_ID}\"
      }
    }
  }" | python3 -c "import sys,json; d=json.load(sys.stdin); print('id:', d.get('id'), 'name:', d.get('name'))"
```
