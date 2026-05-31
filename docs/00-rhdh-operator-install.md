# 00 — Instalação do RHDH via Operador

Este guia cobre a criação de uma instância do Red Hat Developer Hub do zero, partindo de um cluster OpenShift com o operador RHDH já instalado via OperatorHub.

## Ambiente validado

| Item | Valor |
|------|-------|
| Operador | rhdh-operator.v1.9.4 |
| Namespace do operador | openshift-operators |
| Namespace da instância | rhdh-ado-demo |
| API version do CR | rhdh.redhat.com/v1alpha3 |
| Backstage CR name | developer-hub |
| Deployment | backstage-developer-hub |

## Pré-requisitos

- Operador Red Hat Developer Hub instalado via OperatorHub (cluster-scoped)
- Acesso cluster-admin ao cluster
- oc CLI autenticado

Verificar operador instalado:

    oc get csv -n openshift-operators | grep -i rhdh
    oc get crd backstages.rhdh.redhat.com

## Passo 1 — Carregar variáveis de ambiente

IMPORTANTE: sempre carregue as variáveis antes de executar qualquer comando.

    unset RHDH_SECRET OCP_NAMESPACE AZURE_DEVOPS_PAT GITHUB_TOKEN \
      RHDH_CONFIGMAP_APPCONFIG RHDH_CONFIGMAP_PLUGINS RHDH_DEPLOYMENT \
      GITHUB_USER AZURE_DEVOPS_ORG AZURE_DEVOPS_PROJECT

    set -a && source .env && set +a

    echo "OCP_NAMESPACE=${OCP_NAMESPACE}"
    echo "RHDH_SECRET=${RHDH_SECRET}"
    echo "PAT começa com: ${AZURE_DEVOPS_PAT:0:6}"
    echo "GITHUB_TOKEN começa com: ${GITHUB_TOKEN:0:6}"

## Passo 2 — Criar o namespace

    oc new-project ${OCP_NAMESPACE}
    oc get project ${OCP_NAMESPACE}

## Passo 3 — Criar o Secret de variáveis de ambiente

    AZURE_DEVOPS_PAT_BASE64=$(printf ':%s' "${AZURE_DEVOPS_PAT}" | base64)

    oc create secret generic ${RHDH_SECRET} \
      --namespace=${OCP_NAMESPACE} \
      --from-literal=GITHUB_TOKEN=${GITHUB_TOKEN} \
      --from-literal=GITHUB_USER=${GITHUB_USER} \
      --from-literal=GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID} \
      --from-literal=GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET} \
      --from-literal=AZURE_DEVOPS_PAT=${AZURE_DEVOPS_PAT} \
      --from-literal=AZURE_DEVOPS_PAT_BASE64=${AZURE_DEVOPS_PAT_BASE64} \
      --from-literal=AZURE_DEVOPS_ORG=${AZURE_DEVOPS_ORG} \
      --from-literal=AZURE_DEVOPS_PROJECT=${AZURE_DEVOPS_PROJECT}

    oc get secret ${RHDH_SECRET} -n ${OCP_NAMESPACE}

## Passo 4 — Criar o ConfigMap de app-config

    oc create configmap ${RHDH_CONFIGMAP_APPCONFIG} \
      --namespace=${OCP_NAMESPACE} \
      --from-file=app-config.yaml=config/app-config.azure.yaml

## Passo 5 — Criar o ConfigMap de dynamic-plugins

    oc create configmap ${RHDH_CONFIGMAP_PLUGINS} \
      --namespace=${OCP_NAMESPACE} \
      --from-file=dynamic-plugins.yaml=config/dynamic-plugins.yaml

## Passo 6 — Criar a instância Backstage (CR)

    cat <<EOF | oc apply -n ${OCP_NAMESPACE} -f -
    apiVersion: rhdh.redhat.com/v1alpha3
    kind: Backstage
    metadata:
      name: developer-hub
      namespace: ${OCP_NAMESPACE}
    spec:
      application:
        appConfig:
          configMaps:
            - name: ${RHDH_CONFIGMAP_APPCONFIG}
          mountPath: /opt/app-root/src
        dynamicPluginsConfigMapName: ${RHDH_CONFIGMAP_PLUGINS}
        extraEnvs:
          secrets:
            - name: ${RHDH_SECRET}
        replicas: 1
        route:
          enabled: true
      database:
        enableLocalDb: true
    EOF

## Passo 7 — Acompanhar pods

    oc get pods -n ${OCP_NAMESPACE} -w

## Passo 8 — Acessar o RHDH

    oc get route -n ${OCP_NAMESPACE} -o jsonpath='{.items[0].spec.host}'

## Atualizar ConfigMaps (manutenção)

    oc delete configmap ${RHDH_CONFIGMAP_APPCONFIG} -n ${OCP_NAMESPACE}
    oc create configmap ${RHDH_CONFIGMAP_APPCONFIG} \
      --namespace=${OCP_NAMESPACE} \
      --from-file=app-config.yaml=config/app-config.azure.yaml

    oc delete configmap ${RHDH_CONFIGMAP_PLUGINS} -n ${OCP_NAMESPACE}
    oc create configmap ${RHDH_CONFIGMAP_PLUGINS} \
      --namespace=${OCP_NAMESPACE} \
      --from-file=dynamic-plugins.yaml=config/dynamic-plugins.yaml

    oc rollout restart deployment/${RHDH_DEPLOYMENT} -n ${OCP_NAMESPACE}
    oc rollout status deployment/${RHDH_DEPLOYMENT} -n ${OCP_NAMESPACE}

## Notas importantes

- O operador é cluster-scoped — não precisa ser reinstalado por namespace
- O proxy /azure-devops usa AZURE_DEVOPS_PAT_BASE64 do Secret para autenticação
- Variáveis de ambiente NÃO são expandidas no bloco headers do proxy — use o Secret
- O catalog location deve usar URL github.com/blob/ (não raw.githubusercontent.com)

## Próximos passos

- docs/01-prerequisites.md
- docs/02-rhdh-install.md
- docs/03-azure-devops.md
- docs/04-templates.md