# Utpost

Plattform för friluftsdestinationer. Redaktionella guider, användarnas egna turer och bilder.

## Kom igång

Kräver **Docker Desktop** och **Node 22.18+** (`node -v`).

### Sätt 1: allt i Docker

```bash
docker compose up --build -d          # postgres, mongo, api och client (nginx på :3001)
docker compose exec api npm run seed  # första gången: testdata i Postgres
```

Allt nås genom klientens nginx: http://localhost:3001 · http://localhost:3001/api/health (ska svara `"postgres":"ok","mongodb":"ok"`) · http://localhost:3001/graphql (GraphiQL). API:ets egen port är inte publicerad.
Logga in med valfri seedad användare, lösenord `hemligt123` (e-postadresserna syns i `docker compose exec postgres psql -U utpost -c 'select email from users'`).

Stoppa med `docker compose down`. Lägg till `-v` för att även kasta databasernas data.

### Sätt 2: databaserna i Docker, appen med npm (utveckling)

```bash
npm install
docker compose up -d postgres mongo   # bara databaserna, på 5433 och 27017
npm run seed                          # första gången
npm run dev:api                       # API:et på :4000, startar om vid filändring
npm run migrate:logs                  # M5: turloggarna från Postgres till MongoDB (körs om utan dubbletter)
npm run dev:client                    # Vue-klienten på :3001 med hot reload, /api och /graphql proxas till :4000
```

`api/src/config.js` läser `DATABASE_URL` och `MONGO_URL` ur miljön om de finns, annars localhost-adresserna ovan.

## Struktur

- `api/` – Express + Postgres (Drizzle) + MongoDB (driver). REST under `/api`, GraphQL på `/graphql` (`api/src/graphql/`, GraphiQL i browsern på http://localhost:4000/graphql). Relationerna hämtas med DataLoader (`loaders.js`, M5) – en databasfråga per lista, inte per rad; varje svar säger vad det kostade i `extensions.databasfragor`. Turernas mätpunkter ligger i MongoDB sedan M5 (`npm run migrate:logs`). Kräver Node 22.18+ (routes skrivs i TypeScript och körs direkt av Node). `api/Dockerfile` byggs från repots rot.
- `client/` – ny klient i Vue 3 + TypeScript (port 3001). GraphQL med urql (`src/urql.ts`, cache i klienten) och typer genererade ur schemat (`codegen.ts` → `src/gql/`, M5). `client/Dockerfile` är multi-stage: Node bygger, nginx serverar (`client/nginx.conf.template`, renderas vid start).
- `shared/` – API-kontraktet som TypeScript-typer (`@utpost/shared`), används av `api/` och `client/`.
- `web/` – den gamla React-klienten. Portas vy för vy till `client/`, tas bort i M6.
- `infra/azure/` – staging i Azure Container Apps (M6): `staging.yaml` beskriver appen (client + api + postgres + mongo som sidecars), `skapa-staging.sh` skapar den en gång. Pipelinen byter sedan bara image.
- `compose.yaml` – hela miljön. `docs/decisions/` – teamets beslutsdokument.

## Kommandon (kör från roten)

    npm run dev:client        # Vue-klienten på :3001 (API:et måste köra: npm run dev:api)
    npm run lint              # ESLint på client/
    npm run format:check      # Prettier – bara kontroll, ändrar inget
    npm run codegen           # typer ur GraphQL-schemat → client/src/gql/ (körs av typecheck)
    npm run typecheck         # codegen + vue-tsc i client/ + tsc i api/ – kedjan schema → fråga → vy kontrolleras här
    npm test                  # klientens tester (Vitest + Testing Library), en gång, avslutar
    npm run test:api          # integrationstester mot GraphQL-API:et – kräver databaserna igång, seedade och migrerade (M5)
    npm run build             # vite build av client/
    npm run mongo:smoke [id]  # skriver en tur ur Postgres som ett dokument i MongoDB och läser tillbaka
    npm run migrate:logs      # alla turer med mätpunkter → MongoDB, med kontroll av antalet (M5)

## Konfiguration och hemligheter (M6)

Allt som skiljer en miljö från en annan kommer från miljövariabler – se `.env.example`. Koden har standardvärden för lokal utveckling, compose sätter sina, och i molnet sätts de i plattformen. Hemligheter (`JWT_SECRET`, databasadresserna med lösenord) ligger i plattformens *secrets* och refereras från variablerna – de finns inte i någon fil som committas. `client`-imagen läser `API_UPSTREAM` när den startar (nginx-mallen `client/nginx.conf.template`), så samma image fungerar i compose (`api:4000`) och i Azure (`localhost:4000`).

`/api/health` svarar med `sha` – commiten imagen byggdes från (`GIT_SHA`, satt av pipelinen). Så vet man vilken version som kör, och det är så deploysteget vet att molnet har bytt.

## I molnet (M6)

Staging kör i **Azure Container Apps** som en app med fyra containrar (`infra/azure/staging.yaml`). Skapa den en gång med `infra/azure/skapa-staging.sh`, ge pipelinen en identitet med `infra/azure/identitet.sh` (OIDC – inga lösenord i GitHub, bara id:n som variabler på miljön `azure-staging`); därefter deployar pipelinen vid varje merge till `main` (jobbet *Deploy → Azure staging*, se `docs/pipeline.md`): byter image till commitens sha, väntar tills `/api/health` svarar med samma sha, röktestar `/graphql`. Appen skalar till noll mellan passen: första anropet väcker den (räkna med en minut), och databaserna seedas om vid varje kallstart (`SEED_ON_START=1`). Beslutet och alternativen står i `docs/decisions/hosting.md`.

## Images

Pipelinen (jobbet *Image* i `.github/workflows/ci.yml`) bygger `api` och `client` på varje PR och publicerar dem i GHCR vid merge till `main`, taggade med commitens sha:

    ghcr.io/<ägare>/<repo>-api:sha-1a2b3c4
    ghcr.io/<ägare>/<repo>-client:sha-1a2b3c4

## Deploy

Se *I molnet (M6)* ovan: staging skapas en gång med `infra/azure/skapa-staging.sh`, och pipelinen byter image vid varje merge till `main`.
