# Setup

Wardmap has two parts:

- **Backend**: a [Supabase](https://supabase.com) project (hosted Postgres
  database + logins + one small server function).
- **App**: the Flutter app in `lib/`, built for web, Android or iOS.

## 1. Create the backend

1. Create a free project at supabase.com. Note its **Project URL** and
   **publishable key** (Project Settings → API).
2. Install the [Supabase CLI](https://supabase.com/docs/guides/cli), then from
   this folder:

   ```sh
   supabase login
   supabase link --project-ref <your-project-ref>
   supabase db push                      # creates all tables and rules
   supabase secrets set SETUP_KEY=<pick-a-long-random-secret>
   supabase functions deploy manage-staff
   ```

   `supabase/config.toml` lets this function run without Supabase's own login
   check, because the one-time setup call is made before anyone can log in.
   The function checks the login itself for everything else.

3. In the Supabase dashboard, under Authentication → Providers → Email, turn
   **off** "Confirm email" (usernames map to made-up emails that can't receive mail).

## 2. Create a hospital and its admin

**Easiest, from GitHub (no terminal):**

1. **Settings → Secrets and variables → Actions → Secrets**, add
   `SETUP_KEY` (the same value as in Supabase) and `ADMIN_PIN` (the new
   admin's PIN, 6 to 12 digits).
2. **Actions → Add hospital → Run workflow**, fill in the hospital name,
   username and full name, and run it.
3. A green run means the account exists; a red one shows Supabase's answer.

**Or from a terminal:**

Run this for the first hospital, and again for each hospital you add later
(replace the values):

```sh
curl -X POST https://<project-ref>.supabase.co/functions/v1/manage-staff \
  -H "Content-Type: application/json" \
  -H "apikey: <publishable-key>" \
  -d '{"action":"add_hospital","setup_key":"<SETUP_KEY>","hospital_name":"General Hospital",
       "username":"admin","full_name":"Ward Admin","pin":"123456"}'
```

Only someone who knows `SETUP_KEY` can add hospitals. Each hospital's staff
see only their own hospital. Log in as the new admin, then:

1. **Wards tab → New ward** for each ward.
2. Open each ward and use **+** to add its beds.
3. **Team tab → New account** for consultants and senior residents. They can
   then create accounts for their own juniors.

## 3. Run the app

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_KEY=<publishable-key>
```

Optional: `--dart-define=IDLE_MINUTES=10` changes the automatic logout
(default 15 minutes without a tap or key press).

## 4. Host the web app

The repository publishes the web app to **GitHub Pages** every time `main`
changes (`.github/workflows/deploy-web.yml`). One-time setup on GitHub:

1. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
   (Pages on a private repository needs a paid GitHub plan; otherwise make
   the repository public or use the alternative below.)
2. **Settings → Secrets and variables → Actions → Variables**, add
   `SUPABASE_URL` and `SUPABASE_KEY` (the publishable key, which is meant to
   be public). Optionally `IDLE_MINUTES`.
3. Re-run **Actions → Deploy web app**, or push to `main`.

The app is then at `https://<github-user>.github.io/wardmap/`. Staff open
it in a phone browser and use **Add to Home Screen** to get an app icon.

**Alternative:** run `flutter build web` with the `--dart-define`s above and
upload `build/web/` to any static host (Netlify, Cloudflare Pages, a hospital
web server).

## Running the tests

- App: `flutter analyze` and `flutter test`
- Database access rules, on any local Postgres 15+ (no Supabase needed):
  `supabase/tests/run_tests.sh`
- Account function: `deno check supabase/functions/manage-staff/index.ts`

GitHub runs all three on every pull request (`.github/workflows/ci.yml`).
