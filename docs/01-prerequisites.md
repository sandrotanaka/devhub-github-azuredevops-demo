# 01 — Pré-requisitos

Antes de iniciar a instalação, verifique que todos os itens abaixo estão disponíveis.

---

## OpenShift

- Acesso ao cluster com permissão para criar recursos no namespace configurado em `OCP_NAMESPACE`
- `oc` CLI instalado e autenticado:

```bash
oc whoami          # deve retornar seu usuário
oc project "${OCP_NAMESPACE}" # namespace definido no .env
```

## Azure DevOps

- Organização criada em `dev.azure.com`
- Projeto criado dentro da organização
- **PAT (Personal Access Token)** com as permissões:
  - Build: Read & Execute
  - Code: Read
  - Service Connections: Read & Query

Para criar o PAT: `User Settings → Personal Access Tokens → New Token`

## GitHub

- Conta com permissão para criar repositórios públicos (ou privados, se preferir)
- Token de acesso com escopo `repo` configurado no RHDH

## Service Connection GitHub → Azure DevOps

No Azure DevOps, é necessário uma **Service Connection** do tipo GitHub antes de criar pipelines apontando para repositórios GitHub:

1. Acesse `Project Settings → Service connections → New service connection`
2. Selecione **GitHub**
3. Use OAuth ou PAT do GitHub
4. Anote o ID da connection (obtido via script `04-get-connected-service-id.sh`)

## Variáveis de ambiente

Configure o arquivo `.env` antes de executar qualquer script:

```bash
cp .env.example .env
# Edite com seus valores reais
source .env
```

---

## Carregando as variáveis de ambiente

Sempre que abrir um novo terminal, carregue o `.env` antes de executar qualquer comando:

```bash
set -a && source .env && set +a
```

> ⚠️ Não use `export $(cat .env | xargs)` — falha com valores que contêm caracteres especiais como Base64 e `=`.

Confirme que as variáveis estão carregadas:

```bash
echo "ORG: ${AZURE_DEVOPS_ORG}"
echo "PROJECT: ${AZURE_DEVOPS_PROJECT}"
echo "NAMESPACE: ${OCP_NAMESPACE}"
```

---

## Token GitHub (Personal Access Token)

O token GitHub é necessário para que o RHDH leia arquivos de repositórios GitHub (templates, catalog-info.yaml, etc).

### Criar o token

1. Acesse `https://github.com/settings/tokens`
2. Clique em **Generate new token → Generate new token (classic)**
3. Configure:
   - **Note:** `rhdh-demo`
   - **Expiration:** escolha conforme sua política
   - **Scopes:** marque `repo` (para repositórios privados) ou `public_repo` (apenas públicos)
4. Clique em **Generate token** e copie o valor — aparece apenas uma vez

Salve em `.env`:
```bash
GITHUB_TOKEN=<TOKEN_GERADO>
```

### Adicionar ao app-config do RHDH

O RHDH precisa da integração GitHub configurada para ler arquivos de repositórios (templates, `catalog-info.yaml`, `all-templates.yaml`). Sem ela, o erro `NotAllowedError: Reading from 'https://raw.githubusercontent.com/...' is not allowed` ocorre ao tentar importar locations.

Adicione ao `config/app-config.azure.yaml` dentro do bloco `integrations:`:

```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
  azure:
    - host: dev.azure.com
      ...
```

Adicione `GITHUB_TOKEN` ao secret do RHDH:

```bash
B64_GITHUB_TOKEN=$(echo -n "${GITHUB_TOKEN}" | base64)

oc patch secret ${RHDH_SECRET} -n ${OCP_NAMESPACE} \
  --type='json' \
  -p="[{\"op\":\"add\",\"path\":\"/data/GITHUB_TOKEN\",\"value\":\"${B64_GITHUB_TOKEN}\"}]"
```

Aplique o patch no app-config:

```bash
CURRENT=$(oc get configmap ${RHDH_CONFIGMAP_APPCONFIG} -n ${OCP_NAMESPACE} \
  -o jsonpath='{.data.app-config\.azure\.yaml}')

NEW_CONFIG=$(echo "${CURRENT}" | sed "s|integrations:|integrations:\n  github:\n    - host: github.com\n      token: \${GITHUB_TOKEN}|")

oc patch configmap ${RHDH_CONFIGMAP_APPCONFIG} -n ${OCP_NAMESPACE} \
  --type=merge \
  -p "{\"data\":{\"app-config.azure.yaml\":$(echo "${NEW_CONFIG}" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}"
```

Reinicie o RHDH:

```bash
oc rollout restart deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
oc rollout status deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
```
