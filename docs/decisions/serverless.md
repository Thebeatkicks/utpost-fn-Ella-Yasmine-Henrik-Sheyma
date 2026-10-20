# Beslutsdokument: serverless

*Ett av teamets beslutsdokument. Skrivs i M7, hålls levande. Samma mall som `hosting.md`, `api-stil.md` och `databas.md`. Det här dokumentet examinerar Cloud 2 (redogöra för Serverless Framework) – skriv så att en läsare som aldrig har använt Serverless Framework förstår vad det är och varför ni valde som ni gjorde. Det är också underlaget för kunskapsloggens post v.45.*

**Datum:**
**Beslut:** *(en eller två meningar: vad flyttade ni ut ur API:et, vart, och med vilket verktyg skapas och deployas det?)*

## Bakgrund
*Skuld 8: bilduppladdningen skalade om bilder i request-tråden – "timeouts vid last". Vad gjorde `POST /api/photos` före M7 (`resize`, fyra storlekar, signatur), och varför drabbade det alla andra anrop och inte bara uppladdningen? Klistra in före-siffrorna från mätskriptet här eller i tabellen nedan.*

## Alternativ vi jämförde
*Minst tre riktiga alternativ. **Serverless Framework ska vara ett av dem:** vad det är (`serverless.yml` med service, provider, functions, events; `sls deploy`), varför det inte går här (vilka moln stöder v4, vad hände med v3?), och när det hade passat. Förslag på fler: plattformens egna verktyg (Azure Functions Core Tools + `az`, det vi gjorde) · AWS Lambda med SAM · Google Cloud Run functions · Terraform/Pulumi för resurserna · en kö + en worker i API-containern · behålla koden i tråden (och vad som då händer vid last).*

| Alternativ | Vad ändras i repot | Kostnad | För | Emot |
|---|---|---|---|---|
| | | | | |

## Motivering
*Varför det här valet för Utpost just nu? Knyt till mätningen och till vad ni redan har (staging i Azure, OIDC-identiteten från M6, pipelinen).*

## Mätning före/efter
*`node scripts/mat-upload.mjs --n <N> --size 4000x3000` (eller `npm run mat -- --n <N>`). **Före** = bildkoden i API:et, **efter** = API:et anropar funktionen. Samma dator, samma N, samma bildstorlek. Skriv vilket N ni använde och varför.*

| Mätning | Uppladdning p50 | Uppladdning max | Health p50 | Health max | Total tid |
|---|---|---|---|---|---|
| Före, lokalt (N = ) | | | | | |
| Efter, lokalt (N = ) | | | | | |
| Efter, staging (N = ) | | | | | |

*Vad blev snabbare – och vad blev det inte? Varför?*

## Kallstart
*Första anropet efter minst 20 minuters paus (`curl -w '%{time_total}'`, svaret säger `"coldStart": true`) och andra anropet direkt efter. Mät inte direkt efter en deploy – då är funktionen redan varm.*

| Anrop | Tid (curl) | `processingMs` | `coldStart` | `instance` |
|---|---|---|---|---|
| Första efter paus ( min) | | | | |
| Andra | | | | |

*Duger det för en bilduppladdning? Vad skulle ni göra om det inte dög (always-ready, mindre paket, varmhållning – och vad kostar det)?*

## Var koden bor och vad som låser
*Vad är portabelt och vad är det inte? `functions/src/image.js` vet ingenting om Azure. `process-image.js` (`app.http`, `@azure/functions`), `host.json`, `local.settings.json`, `skapa-funktion.sh` och deploysteget i `ci.yml` är Azure. Om ni flyttade till AWS Lambda eller Cloud Run functions i morgon: vilka filer skrivs om, och vilka följer med oförändrade?*

## Konsekvenser
*Vad kostar valet? Pris per körning och per GB-s, gratiskvoten, vad always-ready kostar per timme. Funktionsnyckeln: var finns den (Azure, staging-appens secret – aldrig i repot eller GitHub), hur roteras den? Två deployjobb i stället för ett. Vem i teamet har tillgång till function-appen i portalen?*

**Skrivet av:**
