# Troubleshooting — Erros encontrados e soluções

## 1. Plugin Azure DevOps — npm error ENOENT package.json

**Sintoma:** InstallException ao instalar plugin Azure DevOps
**Causa:** No RHDH 1.9 os plugins Azure DevOps foram migrados para OCI.
**Solução:** Usar referência OCI no dynamic-plugins.yaml:

plugins:
  - disabled: false
    package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops:bs_1.45.3__0.23.0
  - disabled: false
    package: oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/backstage-community-plugin-azure-devops-backend:bs_1.45.3__0.23.0

## 2. Catalog — NotAllowedError raw.githubusercontent.com

**Sintoma:** catalog warn Unable to read url, NotAllowedError
**Causa:** RHDH bloqueia leitura de hosts externos por padrão.
**Solução:** Adicionar ao app-config.yaml:

backend:
  reading:
    allow:
      - host: raw.githubusercontent.com
      - host: dev.azure.com

## 3. Scaffolder — No integration found for location raw.githubusercontent.com

**Sintoma:** InputError: No integration found for location https://raw.githubusercontent.com/...
**Causa:** catalog location usando raw.githubusercontent.com — scaffolder nao mapeia para integracao GitHub.
**Solução:** Usar URL github.com/blob/ no catalog location:

catalog:
  locations:
    - type: url
      target: https://github.com/sandrotanaka/devhub-github-azuredevops-demo/blob/main/templates/all-templates.yaml

## 4. Scaffolder — publish:github not registered

**Sintoma:** NotFoundError: Template action with ID publish:github is not registered.
**Causa:** Plugin scaffolder-backend-module-github nao habilitado.
**Solução:** Adicionar ao dynamic-plugins.yaml:

  - disabled: false
    package: ./dynamic-plugins/dist/backstage-plugin-scaffolder-backend-module-github-dynamic

## 5. Scaffolder — http:backstage:request not registered

**Sintoma:** NotFoundError: Template action with ID http:backstage:request is not registered.
**Causa:** Plugin roadiehq-scaffolder-backend-module-http-request nao habilitado.
**Solução:** Adicionar ao dynamic-plugins.yaml:

  - disabled: false
    package: ./dynamic-plugins/dist/roadiehq-scaffolder-backend-module-http-request-dynamic

## 6. Azure DevOps — Unrecognized value: values no pipeline

**Sintoma:** Unrecognized value: values. Located at position 41 within expression
**Causa:** Sintaxe de escape Nunjucks sendo mal interpretada pelo Azure Pipelines.
**Solução:** Usar sintaxe direta no skeleton azure-pipelines.yml:

steps:
  - script: echo "Build da aplicacao ${{ values.appName }}"
    displayName: 'Build ${{ values.appName }}'

## 7. Git push bloqueado — GitHub Push Protection

**Sintoma:** Push cannot contain secrets — GitHub Personal Access Token
**Causa:** Token GitHub hardcoded no app-config.azure.yaml para debug.
**Solução:**
1. Reverter para token: ${GITHUB_TOKEN} no app-config
2. git commit --amend --no-edit
3. git push --force
4. No cluster usar variavel de ambiente via Secret

## 8. Variaveis de ambiente sobrescrevendo .env

**Sintoma:** source .env nao atualiza variaveis — valores antigos persistem.
**Causa:** Variaveis exportadas na sessao do shell tem precedencia.
**Solução:**
unset RHDH_SECRET OCP_NAMESPACE AZURE_DEVOPS_PAT GITHUB_TOKEN
set -a && source .env && set +a
