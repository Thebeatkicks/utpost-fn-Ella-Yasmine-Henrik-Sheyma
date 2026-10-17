#!/usr/bin/env bash
# En identitet åt pipelinen, utan lösenord (M6). GitHub Actions loggar in i Azure med OIDC:
# jobbet får en kortlivad token av GitHub, och Azure litar på den – men bara för jobb som kör
# i repot REPO och miljön azure-staging, och bara med rätt att ändra resursgruppen RG.
# Körs EN gång per team, efter skapa-staging.sh. Skriver ut raderna för GitHub-miljön.
#
#   REPO=<ägare>/<repo> ./infra/azure/identitet.sh
set -euo pipefail

: "${REPO:?Sätt REPO=<ägare>/<repo>}"
RG="${RG:-utpost-rg}"
APP="${APP:-utpost-staging}"
GH_ENV="${GH_ENV:-azure-staging}"
NAME="${NAME:-${REPO##*/}-github}"

SUB="$(az account show --query id --output tsv)"
TENANT="$(az account show --query tenantId --output tsv)"

echo "→ app registration + service principal: ${NAME}"
APPID="$(az ad app create --display-name "${NAME}" --query appId --output tsv)"
az ad sp create --id "${APPID}" --output none 2>/dev/null || true

echo "→ rollen Contributor på BARA resursgruppen ${RG} (inte hela prenumerationen)"
for i in 1 2 3 4 5 6; do
  if az role assignment create --role Contributor --assignee "${APPID}" --scope "/subscriptions/${SUB}/resourceGroups/${RG}" --output none 2>/dev/null; then break; fi
  echo "   identiteten syns inte än – väntar 10 s (${i}/6)"; sleep 10
done

# GitHub skickar subject med id:n: repo:<ägare>@<ägar-id>/<repo>@<repo-id>:environment:<miljö>.
# Namn räcker inte: ett repo som döps om eller skapas på nytt med samma namn får inte logga in.
IDS="$(curl -fsS "https://api.github.com/repos/${REPO}" | sed -n 's/.*"id": *\([0-9]*\).*/\1/p' | head -1)"
OWNER_ID="$(curl -fsS "https://api.github.com/users/${REPO%%/*}" | sed -n 's/.*"id": *\([0-9]*\).*/\1/p' | head -1)"
SUBJECT="repo:${REPO%%/*}@${OWNER_ID}/${REPO##*/}@${IDS}:environment:${GH_ENV}"
echo "→ federerad identitet, subject: ${SUBJECT}"
az ad app federated-credential create --id "${APPID}" --parameters "{\"name\":\"github-${GH_ENV}\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"${SUBJECT}\",\"audiences\":[\"api://AzureADTokenExchange\"]}" --output none

FQDN="$(az containerapp show --name "${APP}" --resource-group "${RG}" --query properties.configuration.ingress.fqdn --output tsv)"
echo
echo "Klart. Lägg in på GitHub-miljön ${GH_ENV} (variables, inte secrets – ett id är ingen hemlighet):"
echo "  gh api -X PUT repos/${REPO}/environments/${GH_ENV} > /dev/null"
echo "  gh variable set AZURE_CLIENT_ID       --env ${GH_ENV} --repo ${REPO} --body ${APPID}"
echo "  gh variable set AZURE_TENANT_ID       --env ${GH_ENV} --repo ${REPO} --body ${TENANT}"
echo "  gh variable set AZURE_SUBSCRIPTION_ID --env ${GH_ENV} --repo ${REPO} --body ${SUB}"
echo "  gh variable set AZURE_RG              --env ${GH_ENV} --repo ${REPO} --body ${RG}"
echo "  gh variable set AZURE_APP             --env ${GH_ENV} --repo ${REPO} --body ${APP}"
echo "  gh variable set AZURE_URL             --env ${GH_ENV} --repo ${REPO} --body https://${FQDN}"
