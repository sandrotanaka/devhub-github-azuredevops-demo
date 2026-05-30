# Red Hat Developer Hub — Demo com GitHub + Azure DevOps

Repositório de referência para instalação e configuração do [Red Hat Developer Hub (RHDH)](https://developers.redhat.com/rhdh) integrado ao **Azure DevOps**, com template Backstage validado para criação de aplicações Quarkus.

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| OpenShift CLI (`oc`) | 4.12+ |
| Operador RHDH instalado | 1.9+ |
| Azure DevOps | Organização e projeto criados |
| PAT do Azure DevOps | Permissões: Build (R/W), Code (R), Service Connections (R/Q) |
| GitHub | Conta com token de acesso (`repo` ou `public_repo`) |

---

## Estrutura

```
devhub-github-azuredevops-demo/
├── docs/
│   ├── 00-rhdh-operator-install.md  ← instalar RHDH do zero
│   ├── 01-prerequisites.md          ← pré-requisitos e tokens
│   ├── 02-rhdh-install.md           ← configurar instância existente
│   ├── 03-azure-devops.md           ← projeto ADO + Service Connection
│   └── 04-templates.md              ← templates Backstage
├── config/
│   ├── app-config.azure.yaml        ← integração GitHub + Azure
│   └── dynamic-plugins.yaml         ← plugins Azure DevOps (OCI)
├── templates/
│   ├── all-templates.yaml
│   └── quarkus-github-ado/
│       ├── template.yaml
│       └── skeleton/
├── troubleshooting/
│   └── errors.md
└── .env.example                     ← variáveis de ambiente necessárias
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
set -a && source .env && set +a
```

### Instalação do zero (RHDH ainda não instalado)

Siga `docs/00-rhdh-operator-install.md`.

### Configuração de instância existente

Siga `docs/02-rhdh-install.md`.

---

## Referência de ambiente validado

| Item | Valor |
|---|---|
| OpenShift namespace | `tssc-dh` |
| Backstage CR | `developer-hub` |
| ConfigMap app-config | `tssc-developer-hub-app-config` |
| ConfigMap dynamic-plugins | `tssc-developer-hub-dynamic-plugins` |
| Secret de env vars | `tssc-developer-hub-env` |
| Deployment | `backstage-developer-hub` |
| RHDH versão | 1.9 |

> Valores podem ser sobrescritos via `.env`.
