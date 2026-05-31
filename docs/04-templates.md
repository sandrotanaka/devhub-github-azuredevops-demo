# 04 — Templates Backstage

---

## Estrutura

```
templates/
├── all-templates.yaml
└── quarkus-github-ado/
    ├── template.yaml
    └── skeleton/
        ├── catalog-info.yaml
        ├── azure-pipelines.yml
        └── src/
```

---

## O que o template `quarkus-github-ado` faz

1. Gera o código da aplicação Quarkus via `fetch:template`
2. Cria o repositório GitHub via `publish:github`
3. Cria a pipeline no Azure DevOps via `http:backstage:request` (proxy `/azure-devops`)
4. Dispara a primeira execução da pipeline
5. Registra o componente no catálogo via `catalog:register`

---

## Pré-condições

- `AZURE_DEVOPS_PAT_BASE64` presente no Secret do cluster (ver `docs/01-prerequisites.md`)
- `connectedServiceId` correto em `template.yaml` (ver `docs/03-azure-devops.md`)
- Proxy `/azure-devops` configurado em `app-config.azure.yaml`

---

## Como o proxy funciona

O `app-config.azure.yaml` configura um proxy autenticado para a API do Azure DevOps:

```yaml
proxy:
  endpoints:
    /azure-devops:
      target: https://dev.azure.com
      changeOrigin: true
      allowedMethods: [GET, POST, DELETE, PATCH]
      credentials: dangerously-allow-unauthenticated
      headers:
        Authorization: "Basic ${AZURE_DEVOPS_PAT_BASE64}"
```

O header `Authorization` é expandido a partir da variável de ambiente `AZURE_DEVOPS_PAT_BASE64` injetada pelo Secret.

> ⚠️ **Variáveis `${...}` não são expandidas dentro dos steps do template** (`http:backstage:request`). A autenticação é feita pelo proxy, não pelo template diretamente. Não adicione header `Authorization` nos steps — o proxy já o injeta.

---

## Anotações do catalog-info.yaml

O skeleton usa as seguintes anotações para que o plugin Azure DevOps funcione corretamente:

```yaml
annotations:
  backstage.io/source-location: url:https://github.com/${{ values.githubUser }}/${{ values.appName }}
  github.com/project-slug: ${{ values.githubUser }}/${{ values.appName }}
  dev.azure.com/host-org: dev.azure.com/${{ values.adoOrg }}
  dev.azure.com/project: ${{ values.adoProject }}
  dev.azure.com/build-definition: ${{ values.adoOrg }}.${{ values.appName }}
```

> A anotação `dev.azure.com/build-definition` deve corresponder exatamente ao nome da pipeline criada no ADO. O nome é gerado no formato `<adoOrg>.<appName>`.

---

## Registrar templates no catálogo

O `app-config.azure.yaml` já aponta para este repositório:

```yaml
catalog:
  locations:
    - type: url
      target: https://github.com/sandrotanaka/devhub-github-azuredevops-demo/blob/main/templates/all-templates.yaml
      rules:
        - allow: [Template]
```

Após qualquer mudança no `app-config`, atualize o ConfigMap e reinicie:

```bash
oc create configmap ${RHDH_CONFIGMAP_APPCONFIG} \
  --from-file=app-config.yaml=config/app-config.azure.yaml \
  -n ${OCP_NAMESPACE} \
  --dry-run=client -o yaml | oc apply -f -

oc rollout restart deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
oc rollout status deployment/backstage-developer-hub -n ${OCP_NAMESPACE}
```

---

## Troubleshooting de templates

**Pipeline não criada no ADO:**

Verifique se `AZURE_DEVOPS_PAT_BASE64` está no Secret:
```bash
oc exec deployment/backstage-developer-hub -n ${OCP_NAMESPACE} -- env | grep PAT_BASE64
```

Crie manualmente via curl como fallback (ver `docs/03-azure-devops.md`).

**Aba Azure Pipelines - CI vazia:**

Verifique se o nome da pipeline no ADO bate com a anotação `dev.azure.com/build-definition`:
```bash
curl -sk -u ":${AZURE_DEVOPS_PAT}" \
  "https://dev.azure.com/${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/build/definitions?api-version=7.1" \
  | python3 -c "import sys,json; [print(p['name']) for p in json.load(sys.stdin).get('value',[])]"
```

**Error: Expected "dev.azure.com" annotations were not found:**

O `catalog-info.yaml` do componente está faltando as anotações `dev.azure.com/*`. Edite diretamente no GitHub ou recrie o componente com o template corrigido.

**Templates não aparecem em Create:**

Verifique se o catalog processou a location:
```bash
oc logs deployment/backstage-developer-hub -n ${OCP_NAMESPACE} | grep -i "template\|location\|error"
```
