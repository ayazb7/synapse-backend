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
  username: z.string().min(1),
  remember: z.boolean().optional().default(false),
});

const SigninSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  remember: z.boolean().optional().default(false),
});

export function buildAuthRouter({ supabase }: BuildAuthRouterArgs) {
  const router = Router();

  router.post('/signup', async (req, res) => {
    const parse = SignupSchema.safeParse(req.body);
    if (!parse.success) return res.status(400).json({ error: parse.error.flatten() });
    const { email, password, username, remember } = parse.data;

    const options: any = { data: { username } };
    if (env.FRONTEND_URL) {
      options.emailRedirectTo = `${env.FRONTEND_URL}/auth/callback`;
    }
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options,
    });
    if (error) return res.status(400).json({ error: error.message });

    if (data.session) {
      const maxAge = remember ? 60 * 60 * 24 * 60 : undefined; // 60 days
      res.cookie(env.ACCESS_COOKIE_NAME, data.session.access_token, {
        httpOnly: true,
        sameSite: 'lax',
        secure: process.env.NODE_ENV === 'production',
        maxAge,
      });
      res.cookie(env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
        httpOnly: true,
        sameSite: 'lax',
        secure: process.env.NODE_ENV === 'production',
        maxAge,
      });
    }

    return res.status(201).json({ user: data.user });
  });

  router.post('/signin', async (req, res) => {
    const parse = SigninSchema.safeParse(req.body);
    if (!parse.success) return res.status(400).json({ error: parse.error.flatten() });
    const { email, password, remember } = parse.data;

    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return res.status(401).json({ error: error.message });

    const maxAge = remember ? 60 * 60 * 24 * 60 : undefined; // 60 days
    res.cookie(env.ACCESS_COOKIE_NAME, data.session.access_token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      maxAge,
    });
    res.cookie(env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      maxAge,
    });
    return res.json({ user: data.user });
  });

  router.post('/signout', async (_req, res) => {
    res.clearCookie(env.ACCESS_COOKIE_NAME);
    res.clearCookie(env.REFRESH_COOKIE_NAME);
    return res.status(204).send();
  });

  // Sets cookies from tokens coming from email link
  router.post('/set-session', async (req, res) => {
    const schema = z.object({
      access_token: z.string(),
      refresh_token: z.string(),
      remember: z.boolean().optional().default(false),
    });
    const parsed = schema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const { access_token, refresh_token, remember } = parsed.data;

    // Validate tokens by fetching user
    const { data, error } = await supabase.auth.getUser(access_token);
    if (error || !data.user) return res.status(401).json({ error: 'Invalid tokens' });

    const maxAge = remember ? 60 * 60 * 24 * 60 : undefined;
    res.cookie(env.ACCESS_COOKIE_NAME, access_token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      maxAge,
    });
    res.cookie(env.REFRESH_COOKIE_NAME, refresh_token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      maxAge,
    });
    return res.status(200).json({ ok: true });
  });

  return router;
}


