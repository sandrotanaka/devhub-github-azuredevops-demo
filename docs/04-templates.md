# 04 — Templates Backstage

---

## Estrutura

```
templates/
├── all-templates.yaml                  ← ponto de entrada do catálogo
└── quarkus-github-ado/
    ├── template.yaml                   ← definição do template
    └── skeleton/
        ├── catalog-info.yaml           ← registrado no catálogo RHDH
        ├── azure-pipelines.yml         ← pipeline ADO gerada com a app
        └── src/                        ← app Quarkus mínima
```

---

## O que o template `quarkus-github-ado` faz

1. **Cria um repositório GitHub** com o código da aplicação Quarkus e o `azure-pipelines.yml`
2. **Cria uma pipeline no Azure DevOps** via API REST apontando para o repo GitHub
3. **Dispara a primeira execução** da pipeline
4. **Registra o componente no catálogo** do RHDH via `catalog-info.yaml`

---

## Pré-condições para usar o template

- Service Connection GitHub configurada no ADO (ver `docs/03-azure-devops.md`)
- `AZURE_GITHUB_SERVICE_CONNECTION_ID` preenchido no `.env`
- PAT Base64 atualizado em `template.yaml` (campo `Authorization` dos steps `create-pipeline` e `run-pipeline`)

---

## Atualizar o PAT Base64 no template

O header `Authorization` nos steps do template **não expande variáveis de ambiente**. O valor precisa ser hardcoded:

```bash
source .env
echo -n ":${AZURE_DEVOPS_PAT}" | base64
```

Substitua `<BASE64_HARDCODED_DO_PAT>` no arquivo `templates/quarkus-github-ado/template.yaml`.

---

## Apontando o catálogo para este repositório

O `app-config.azure.yaml` já está configurado para buscar templates neste repositório GitHub:

```yaml
catalog:
  locations:
    - type: url
      target: https://raw.githubusercontent.com/${GITHUB_USER}/devhub-github-azuredevops-demo/main/templates/all-templates.yaml
```

Após o `oc rollout restart`, o RHDH carrega automaticamente os templates desta URL.
