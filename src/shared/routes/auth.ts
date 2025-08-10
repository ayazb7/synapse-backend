import { Router } from 'express';
import type { SupabaseClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { env } from '../env';

type BuildAuthRouterArgs = {
  supabase: SupabaseClient;
};

const SignupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  full_name: z.string().min(1),
});

const SigninSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export function buildAuthRouter({ supabase }: BuildAuthRouterArgs) {
  const router = Router();

  router.post('/signup', async (req, res) => {
    const parse = SignupSchema.safeParse(req.body);
    if (!parse.success) return res.status(400).json({ error: parse.error.flatten() });
    const { email, password, full_name } = parse.data;

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name,
        },
      },
    });
    if (error) return res.status(400).json({ error: error.message });

    // set cookies if session present (depends on email confirmation settings)
    if (data.session) {
      res.cookie(env.ACCESS_COOKIE_NAME, data.session.access_token, {
        httpOnly: true,
        sameSite: 'lax',
        secure: process.env.NODE_ENV === 'production',
      });
      res.cookie(env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
        httpOnly: true,
        sameSite: 'lax',
        secure: process.env.NODE_ENV === 'production',
      });
    }

    return res.status(201).json({ user: data.user });
  });

  router.post('/signin', async (req, res) => {
    const parse = SigninSchema.safeParse(req.body);
    if (!parse.success) return res.status(400).json({ error: parse.error.flatten() });
    const { email, password } = parse.data;

    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return res.status(401).json({ error: error.message });

    res.cookie(env.ACCESS_COOKIE_NAME, data.session.access_token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
    });
    res.cookie(env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
    });
    return res.json({ user: data.user });
  });

  router.post('/signout', async (_req, res) => {
    res.clearCookie(env.ACCESS_COOKIE_NAME);
    res.clearCookie(env.REFRESH_COOKIE_NAME);
    return res.status(204).send();
  });

  return router;
}


