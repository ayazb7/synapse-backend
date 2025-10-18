import type { Request, Response, NextFunction } from 'express';
import type { SupabaseClient } from '@supabase/supabase-js';
import { env } from '../env';

type BuildAuthMiddlewareArgs = {
  supabase: SupabaseClient;
};

export function authMiddleware({ supabase }: BuildAuthMiddlewareArgs) {
  return async function ensureAuth(req: Request, res: Response, next: NextFunction) {
    try {
      const cookieAccessToken = req.cookies?.[env.ACCESS_COOKIE_NAME] as string | undefined;
      const cookieRefreshToken = req.cookies?.[env.REFRESH_COOKIE_NAME] as string | undefined;
      const authHeader = req.header('authorization') || req.header('Authorization');
      const headerAccessToken = authHeader?.toLowerCase().startsWith('bearer ')
        ? authHeader.slice(7).trim()
        : undefined;

      const accessToken = cookieAccessToken || headerAccessToken;
      console.log('Auth middleware - Access token present (cookie/header):', !!cookieAccessToken, !!headerAccessToken);
      if (authHeader) {
        console.log('Auth middleware - Authorization header detected');
      }
      console.log('Auth middleware - Cookies:', Object.keys(req.cookies || {}));
      
      if (!accessToken) {
        console.log('Auth middleware - No access token found');
        return res.status(401).json({ error: 'Not authenticated - no token' });
      }

      const { data, error } = await supabase.auth.getUser(accessToken);
      
      if (error || !data.user) {
        console.warn('Auth middleware - Access token invalid or no user. Attempting refresh...');
        if (!cookieRefreshToken) {
          return res.status(401).json({ error: 'Invalid session' });
        }
        try {
          const { data: refreshed, error: rErr } = await supabase.auth.refreshSession({ refresh_token: cookieRefreshToken });
          if (rErr || !refreshed?.session || !refreshed?.user) {
            console.error('Auth middleware - Refresh failed:', rErr?.message);
            return res.status(401).json({ error: 'Session expired' });
          }

          const isProduction = process.env.NODE_ENV === 'production';
          const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
          const cookieOptions = {
            httpOnly: true,
            sameSite: isProduction ? 'none' as const : 'lax' as const,
            secure: isProduction,
            maxAge: THIRTY_DAYS_MS,
            domain: isProduction ? undefined : undefined,
          };
          // Rotate cookies
          res.cookie(env.ACCESS_COOKIE_NAME, refreshed.session.access_token, cookieOptions);
          res.cookie(env.REFRESH_COOKIE_NAME, refreshed.session.refresh_token, cookieOptions);

          (req as any).user = refreshed.user;
          return next();
        } catch (e) {
          console.error('Auth middleware - Unexpected refresh error:', e);
          return res.status(401).json({ error: 'Session expired' });
        }
      }

      console.log('Auth middleware - User authenticated:', data.user.id);
      (req as any).user = data.user;
      next();
    } catch (error) {
      console.error('Auth middleware - Unexpected error:', error);
      return res.status(500).json({ error: 'Authentication error' });
    }
  };
}


