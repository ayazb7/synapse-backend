import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { createClient } from '@supabase/supabase-js';
import { env } from './shared/env';
import { buildAuthRouter } from './shared/routes/auth';
import { authMiddleware } from './shared/middleware/authMiddleware';

const app = express();

app.use(helmet());
app.use(express.json());
app.use(cookieParser());
app.use(
  cors({
    origin: env.CORS_ORIGIN ?? true,
    credentials: true,
  })
);

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  auth: {
    persistSession: false,
    detectSessionInUrl: false,
  },
});

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.use('/auth', buildAuthRouter({ supabase }));

app.get('/me', authMiddleware({ supabase }), async (req, res) => {
  const user = (req as any).user;
  res.json({ user });
});

app.listen(env.PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`API listening on http://localhost:${env.PORT}`);
});


