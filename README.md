```

```

### Synapse Backend API (Supabase Auth)

Environment:

1. Copy `.env.example` to `.env` and fill values:

```
PORT=4000
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
CORS_ORIGIN=http://localhost:5173
```

Run:

```
npm run dev
```

HTTP Endpoints:

- POST `/auth/signup` { email, password, full_name }
- POST `/auth/signin` { email, password }
- POST `/auth/signout`
- GET `/me` (requires cookies)

Database (SQL) for `public.users` and trigger to mirror auth users is in `sql/001_users.sql`.
