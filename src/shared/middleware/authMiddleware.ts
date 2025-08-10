import type { Request, Response, NextFunction } from 'express';
import type { SupabaseClient } from '@supabase/supabase-js';
import { env } from '../env';

type BuildAuthMiddlewareArgs = {
  supabase: SupabaseClient;
};

export function authMiddleware({ supabase }: BuildAuthMiddlewareArgs) {
  return async function ensureAuth(req: Request, res: Response, next: NextFunction) {
    const accessToken = req.cookies?.[env.ACCESS_COOKIE_NAME] as string | undefined;
    if (!accessToken) return res.status(401).json({ error: 'Not authenticated' });

    const { data, error } = await supabase.auth.getUser(accessToken);
    if (error || !data.user) return res.status(401).json({ error: 'Invalid session' });

    (req as any).user = data.user;
    next();
  };
}


