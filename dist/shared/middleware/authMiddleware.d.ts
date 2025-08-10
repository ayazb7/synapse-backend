import type { Request, Response, NextFunction } from 'express';
import type { SupabaseClient } from '@supabase/supabase-js';
type BuildAuthMiddlewareArgs = {
    supabase: SupabaseClient;
};
export declare function authMiddleware({ supabase }: BuildAuthMiddlewareArgs): (req: Request, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>> | undefined>;
export {};
//# sourceMappingURL=authMiddleware.d.ts.map