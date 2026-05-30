# 03 — Integração com Azure DevOps

---

## Passo 1 — Criar o projeto ADO

1. Acesse `https://dev.azure.com/<SUA_ORG>`
2. Clique em **New project**
3. Preencha:
   - **Project name:** `rhdh-ado-demo` (ou o nome definido em `AZURE_DEVOPS_PROJECT`)
   - **Visibility:** Private
4. Clique em **Create**

---

## Passo 2 — Criar o PAT (Personal Access Token)

1. No Azure DevOps, clique no ícone do usuário (canto superior direito)
2. Acesse **User settings → Personal Access Tokens**
3. Clique em **New Token**
4. Configure:
   - **Name:** `rhdh-demo`
   - **Organization:** selecione sua organização
   - **Expiration:** escolha conforme sua política
   - **Scopes:** selecione **Custom defined** e habilite **todos** os escopos abaixo:

     | Escopo | Permissão |
     |---|---|
     | Build | Read & Execute |
     | Code | Read |
     | **Service Connections** | **Read & Query** |
     | Project and Team | Read |

     > ⚠️ O escopo **Service Connections** é obrigatório. Sem ele, o comando do Passo 4 retorna `401 Unauthorized` com resposta vazia.

5. Clique em **Create** e copie o token gerado — ele só aparece uma vez

Salve o valor em `.env`:
```bash
AZURE_DEVOPS_PAT=<TOKEN_GERADO>
```

Para atualizar um PAT já existente: acesse `https://dev.azure.com/<SUA_ORG>/_usersSettings/tokens`, clique no PAT → **Edit** → adicione o escopo faltante → **Save**.

---

## Passo 3 — Criar a Service Connection GitHub

A Service Connection permite que o Azure DevOps acesse repositórios GitHub para criar e executar pipelines.

1. Acesse `https://dev.azure.com/<SUA_ORG>/<SEU_PROJETO>/_settings/adminservices`
   - Ou: **Project Settings → Service connections**
2. Clique em **New service connection**
3. Selecione **GitHub** e clique em **Next**
4. Escolha o método de autenticação:
   - **Personal Access Token**: use um PAT do GitHub com escopos `repo, user, admin:repo_hook`
   - **Grant authorization** (OAuth): autoriza via browser
5. Clique em **Verify** — aguarde **Verification Succeeded**
6. Preencha o **Service Connection Name** (ex: `github-sandrotanaka`)
7. Marque **Grant access permission to all pipelines**
8. Clique em **Verify and save**

---

## Passo 4 — Obter o ID da Service Connection

O `connectedServiceId` é necessário no `template.yaml` para que a pipeline ADO acesse o repositório GitHub.

```bash
curl -sk -u ":${AZURE_DEVOPS_PAT}" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/serviceendpoint/endpoints?type=GitHub&api-version=7.1" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
conns = data.get('value', [])
if not conns:
    print('Nenhuma Service Connection GitHub encontrada.')
    print('Crie em: Project Settings → Service connections → New → GitHub')
else:
    for c in conns:
        print(f'ID:   {c[\"id\"]}')
        print(f'Nome: {c[\"name\"]}')
"
```

> Se retornar `401 Unauthorized` ou resposta vazia: o PAT não tem o escopo **Service Connections: Read & Query**. Atualize o PAT conforme o Passo 2.

Copie o ID retornado e salve em `.env`:
```bash
AZURE_GITHUB_SERVICE_CONNECTION_ID=<ID_RETORNADO>
```

Substitua também `<ID_DA_SERVICE_CONNECTION_GITHUB>` em `templates/quarkus-github-ado/template.yaml`.

---

## Convenção de nomes de pipeline

Quando o template cria a pipeline via API apontando para um repositório GitHub, o Azure DevOps nomeia a pipeline automaticamente como:

```
<adoOrg>.<appName>
```

Exemplo: organização `minha-org`, app `minha-api` → pipeline `minha-org.minha-api`.

Por isso a anotação no `catalog-info.yaml` usa:

```yaml
dev.azure.com/build-definition: ${{ values.adoOrg }}.${{ values.appName }}
```

---

## Verificando a integração

Após o deploy de uma aplicação via template, acesse o componente no catálogo do RHDH. A aba **CI** deve mostrar as execuções da pipeline ADO.

Se a aba aparecer vazia, verifique:

```bash
# 1. Plugins inicializados
oc logs -n tssc-dh deployment/backstage-developer-hub \
  -c backstage-backend | grep -i azure

# 2. Anotações do catalog-info.yaml estão corretas:
#    dev.azure.com/project: <projeto>
#    dev.azure.com/build-definition: <org>.<appName>

# 3. Nome da pipeline no ADO bate com o valor de build-definition
curl -sk -u ":${AZURE_DEVOPS_PAT}" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/build/definitions?api-version=7.1" \
  | python3 -c "
import sys, json
for p in json.load(sys.stdin).get('value', []):
    print(p['name'])
"
```
