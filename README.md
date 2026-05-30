# Red Hat Developer Hub — Demo com Azure DevOps

Repositório de referência para instalação e configuração do [Red Hat Developer Hub (RHDH)](https://developers.redhat.com/rhdh) integrado ao **Azure DevOps**, com template Backstage validado para criação de aplicações Quarkus.

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| OpenShift CLI (`oc`) | 4.12+ |
| Acesso ao cluster OpenShift | namespace `tssc-dh` criado |
| Azure DevOps | Organização e projeto criados |
| PAT do Azure DevOps | Permissões: Build (R/W), Code (R), Service Connections (R) |
| GitHub | Conta com permissão para criar repositórios |

---

## Estrutura

```
devhub-github-azuredevops-demo/
├── docs/                        # Passo a passo da instalação
│   ├── 01-prerequisites.md
│   ├── 02-rhdh-install.md
│   ├── 03-azure-devops.md
│   └── 04-templates.md
├── config/                      # YAMLs dos ConfigMaps (sem valores sensíveis)
│   ├── app-config.azure.yaml
│   └── dynamic-plugins.yaml
├── scripts/                     # Shell scripts por etapa
│   ├── 01-create-secret.sh
│   ├── 02-patch-configmap.sh
│   ├── 03-restart-rhdh.sh
│   └── 04-get-connected-service-id.sh
├── templates/                   # Templates Backstage
│   ├── all-templates.yaml
│   └── quarkus-github-ado/
│       ├── template.yaml
│       └── skeleton/
├── troubleshooting/
│   └── errors.md
└── .env.example                 # Variáveis de ambiente necessárias
```

---

## Início rápido

```bash
# 1. Clone o repositório
git clone https://github.com/<SEU_USUARIO>/devhub-github-azuredevops-demo.git
cd devhub-github-azuredevops-demo

# 2. Configure as variáveis de ambiente
cp .env.example .env
# Edite .env com seus valores reais

# 3. Carregue as variáveis
source .env

# 4. Execute os scripts em ordem
bash scripts/01-create-secret.sh
bash scripts/02-patch-configmap.sh
bash scripts/03-restart-rhdh.sh
```

Consulte [`docs/`](./docs/) para o guia completo passo a passo.

---

## Referência de ambiente

| Item | Valor padrão |
|---|---|
| OpenShift namespace | `tssc-dh` |
| Backstage CR | `developer-hub` |
| ConfigMap app-config | `tssc-developer-hub-app-config` |
| ConfigMap dynamic-plugins | `tssc-developer-hub-dynamic-plugins` |
| Secret de env vars | `tssc-developer-hub-env` |

Todos os valores podem ser sobrescritos via `.env`.
