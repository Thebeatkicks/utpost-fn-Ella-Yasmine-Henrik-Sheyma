// API-kontraktet för Utpost – det som faktiskt går över tråden i dag.
//
// Fälten heter som kolumnerna i Postgres (snake_case) eftersom API:et svarar med
// `select *`. Det är ett medvetet val för M2: kontraktet ska beskriva verkligheten,
// inte önskan. Att döpa om fälten är ett eget beslut (och försvinner i praktiken
// när API:et blir GraphQL).
//
// Regeln: ändras ett svar i api/ ändras typen här – i samma PR.

export type Difficulty = 'lätt' | 'medel' | 'svår'

export interface Guide {
  id: number
  slug: string
  title: string
  region: string
  difficulty: Difficulty
  length_km: number
  body_html: string
  hero_image: string | null
  published: boolean
  author_id: number | null
  updated_at: string
}

export interface User {
  id: number
  email: string
  display_name: string
  role: 'member' | 'editor'
  created_at: string
}

export interface TourLog {
  id: number
  tour_id: number
  recorded_at: string
  lat: number
  lon: number
  elevation_m: number | null
  heart_rate: number | null
  note: string | null
}

export interface Photo {
  id: number
  tour_id: number
  filename: string
  width: number
  height: number
  created_at: string
}

export interface Tour {
  id: number
  user_id: number
  guide_id: number | null
  title: string
  started_at: string
  distance_m: number
  notes: string | null
}

/** POST /api/photos (M7) – klienten skickar bara mått och filnamn, inga bytes än */
export interface PhotoUploadRequest {
  tourId: number
  filename: string
  width: number
  height: number
}

/** En omskalad variant: bredd i pixlar och bildsignaturen (för att hitta dubbletter) */
export interface PhotoVariant {
  size: number
  signature: string
}

/** Svaret på POST /api/photos (M7): raden + det funktionen process-image räknade ut */
export interface PhotoUploadResponse extends Photo {
  variants: PhotoVariant[]
  /** funktionens tid för själva bildarbetet */
  processingMs: number
  /** true = första anropet i en ny funktionsprocess */
  coldStart: boolean
  /** vilken funktionsinstans som svarade */
  instance: string
  /** API:ets tid för hela anropet: databasen + funktionen + nätet */
  apiMs: number
}

/** GET /api/tours – varje tur med sina relationer inbakade */
export interface TourWithRelations extends Tour {
  user: User
  guide: Guide | null
  photos: Photo[]
  logs: TourLog[]
}

/** GET /api/tours/:id */
export interface TourDetail extends Tour {
  logs: TourLog[]
  photos: Photo[]
}

/** POST /api/auth/login */
export interface LoginRequest {
  email: string
  password: string
}
export interface LoginResponse {
  token: string
  // OBS: i dag skickar API:et hela databasraden, inklusive password_hash.
  // Typen säger User – verkligheten säger mer. TypeScript tar inte bort fält,
  // det här är en säkerhetsskuld (skuld 9) som lagas i M8, inte här.
  user: User
}

/** Felsvar från API:et: { error: '...' } */
export interface ApiError {
  error: string
}
