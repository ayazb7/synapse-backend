import { Router } from 'express';
import type { SupabaseClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { env } from '../env';

type BuildAuthRouterArgs = {
  supabase: SupabaseClient;
  supabaseAdmin: SupabaseClient;
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

export function buildAuthRouter({ supabase, supabaseAdmin }: BuildAuthRouterArgs) {
  const router = Router();

  router.post('/signup', async (req, res) => {
    const parse = SignupSchema.safeParse(req.body);
    if (!parse.success) return res.status(400).json({ error: parse.error.flatten() });
    const { email, password, username, remember } = parse.data;

    try {
      const existingRes: any = await (supabaseAdmin as any).auth.admin.getUserByEmail(email);
      const existingUser = existingRes?.data?.user;
      if (existingUser) {
        return res.status(409).json({ error: 'An account with this email already exists. Please sign in instead.' });
      }
    } catch (e) {
    }

    const options: any = { data: { username } };
    if (env.FRONTEND_URL) {
      options.emailRedirectTo = `${env.FRONTEND_URL}/auth/callback`;
    }
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options,
    });
    if (error) {
      const message = String(error.message || '').toLowerCase();
      if (message.includes('already registered') || message.includes('user already')) {
        return res.status(409).json({ error: 'An account with this email already exists. Please sign in instead.' });
      }
      return res.status(400).json({ error: error.message });
    }

    const identities = (data as any)?.user?.identities;
    if (Array.isArray(identities) && identities.length === 0) {
      return res.status(409).json({ error: 'An account with this email already exists. Please sign in instead.' });
    }

    if (data.session) {
      const maxAge = remember ? 60 * 60 * 24 * 60 * 1000 : undefined; // 60 days in milliseconds
      const isProduction = process.env.NODE_ENV === 'production';
      const cookieOptions = {
        httpOnly: true,
        sameSite: isProduction ? 'none' as const : 'lax' as const,
        secure: isProduction,
        maxAge,
        domain: isProduction ? undefined : undefined, // Let browser handle domain
      };
      
      res.cookie(env.ACCESS_COOKIE_NAME, data.session.access_token, cookieOptions);
      res.cookie(env.REFRESH_COOKIE_NAME, data.session.refresh_token, cookieOptions);
    }

    return res.status(201).json({
      user: data.user,
      access_token: data.session?.access_token,
      refresh_token: data.session?.refresh_token,
    });
  });

  router.post('/signin', async (req, res) => {
    const parse = SigninSchema.safeParse(req.body);
    if (!parse.success) return res.status(400).json({ error: parse.error.flatten() });
    const { email, password, remember } = parse.data;

    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return res.status(401).json({ error: error.message });

    const maxAge = remember ? 60 * 60 * 24 * 60 * 1000 : undefined; // 60 days in milliseconds
    const isProduction = process.env.NODE_ENV === 'production';
    const cookieOptions = {
      httpOnly: true,
      sameSite: isProduction ? 'none' as const : 'lax' as const,
      secure: isProduction,
      maxAge,
      domain: isProduction ? undefined : undefined, // Let browser handle domain
    };
    
    res.cookie(env.ACCESS_COOKIE_NAME, data.session.access_token, cookieOptions);
    res.cookie(env.REFRESH_COOKIE_NAME, data.session.refresh_token, cookieOptions);
    return res.json({
      user: data.user,
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
    });
  });

  router.post('/signout', async (_req, res) => {
    const isProduction = process.env.NODE_ENV === 'production';
    const clearOptions = {
      httpOnly: true,
      sameSite: isProduction ? 'none' as const : 'lax' as const,
      secure: isProduction,
      domain: isProduction ? undefined : undefined,
    };
    
    res.clearCookie(env.ACCESS_COOKIE_NAME, clearOptions);
    res.clearCookie(env.REFRESH_COOKIE_NAME, clearOptions);
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

    const maxAge = remember ? 60 * 60 * 24 * 60 * 1000 : undefined; // 60 days in milliseconds
    const isProduction = process.env.NODE_ENV === 'production';
    const cookieOptions = {
      httpOnly: true,
      sameSite: isProduction ? 'none' as const : 'lax' as const,
      secure: isProduction,
      maxAge,
      domain: isProduction ? undefined : undefined, // Let browser handle domain
    };
    
    res.cookie(env.ACCESS_COOKIE_NAME, access_token, cookieOptions);
    res.cookie(env.REFRESH_COOKIE_NAME, refresh_token, cookieOptions);
    return res.status(200).json({ ok: true });
  });

  return router;
}


