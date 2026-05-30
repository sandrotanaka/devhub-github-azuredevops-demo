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
