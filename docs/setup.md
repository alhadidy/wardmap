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

## 2. Create the first hospital and admin

Run once (replace the values):

```sh
curl -X POST https://<project-ref>.supabase.co/functions/v1/manage-staff \
  -H "Content-Type: application/json" \
  -d '{"action":"setup","setup_key":"<SETUP_KEY>","hospital_name":"General Hospital",
       "username":"admin","full_name":"Ward Admin","pin":"123456"}'
```

This only works while there are no accounts. Log in as that admin and create
everyone else from the Team tab. Wards and beds are added by the admin (the
screens for that come in step 2; until then use the Supabase table editor).

## 3. Run the app

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_KEY=<publishable-key>
```

Build the website with `flutter build web` and the same two `--dart-define`s;
the result is in `build/web/` and can be hosted anywhere that serves files.

## Running the tests

- App: `flutter test`
- Database access rules, on any local Postgres 15+ (no Supabase needed):
  `supabase/tests/run_tests.sh`
