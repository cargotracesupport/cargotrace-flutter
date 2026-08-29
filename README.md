# CargoTrace Driver (Flutter)

Native driver app for CargoTrace. It reuses the existing backend — the same
Supabase project and the deployed Next.js API — so nothing on the web side
changes. This repo is **separate** from the Next.js repo (`CargoTraceWeb`).

App id: `app.cargotrace.driver`

## Why native (vs. the web app)
The one thing a browser can't do: **background GPS** — stream the driver's
location while the phone is locked or another app is open, posting to
`/api/track`. Everything else (login, trips, status changes, live updates) works
against Supabase directly, protected by the same Row-Level Security as the site.

## Architecture
- **Auth / data / realtime:** `supabase_flutter`, using the classic anon key.
  RLS is the guard; the `service_role` key never ships in the app.
- **Role gate:** drivers' credentials are the same accounts as the website. After
  login the app reads `profiles.role`; non-drivers are shown "use the web
  dashboard" (mirrors the site routing admin→/admin, agent→/agent, driver→/driver).
- **GPS ingest (next milestones):** posts to the deployed `/api/track`. That
  endpoint currently authenticates by session cookie; the mobile app holds a
  Bearer JWT, so it needs a small additive change to also accept
  `Authorization: Bearer` (web cookie path unchanged).

## Structure
```
lib/
  config.dart            # Supabase URL + anon key (public), API base URL
  data/db.dart           # shared Supabase client
  main.dart              # init + AuthGate
  auth/login_screen.dart # email/password sign-in
  auth/role_gate.dart    # driver-only gate
  trips/trips_screen.dart# driver home (live query = next milestone)
```

## Run
```
flutter pub get
flutter run                       # needs a booted Android/iOS device
```
Optional deployed API base for GPS:
```
flutter run --dart-define=API_BASE_URL=https://<your-deployed-app>
```

## Milestones
- [x] Scaffold + login + driver role gate
- [ ] Trips list (live Supabase query + realtime)
- [ ] Trip detail + status actions (start / confirm pickup / mark delivered)
- [ ] Foreground GPS → /api/track
- [ ] Background GPS (foreground service, permissions)
- [ ] Maps (pickup → drop-off)
