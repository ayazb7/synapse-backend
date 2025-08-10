import type { SupabaseClient } from '@supabase/supabase-js';
type BuildAuthRouterArgs = {
    supabase: SupabaseClient;
};
export declare function buildAuthRouter({ supabase }: BuildAuthRouterArgs): import("express-serve-static-core").Router;
export {};
//# sourceMappingURL=auth.d.ts.map