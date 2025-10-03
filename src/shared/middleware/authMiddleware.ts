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
      
      if (error) {
        console.error('Auth middleware - Supabase error:', error);
        return res.status(401).json({ error: 'Invalid session - ' + error.message });
      }
      
      if (!data.user) {
        console.log('Auth middleware - No user data returned');
        return res.status(401).json({ error: 'Invalid session - no user' });
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


