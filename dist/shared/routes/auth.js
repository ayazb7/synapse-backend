"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildAuthRouter = buildAuthRouter;
const express_1 = require("express");
const zod_1 = require("zod");
const env_1 = require("../env");
const SignupSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(6),
    username: zod_1.z.string().min(1),
    remember: zod_1.z.boolean().optional().default(false),
});
const SigninSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(6),
    remember: zod_1.z.boolean().optional().default(false),
});
function buildAuthRouter({ supabase }) {
    const router = (0, express_1.Router)();
    router.post('/signup', async (req, res) => {
        const parse = SignupSchema.safeParse(req.body);
        if (!parse.success)
            return res.status(400).json({ error: parse.error.flatten() });
        const { email, password, username, remember } = parse.data;
        const options = { data: { username } };
        if (env_1.env.FRONTEND_URL) {
            options.emailRedirectTo = `${env_1.env.FRONTEND_URL}/auth/callback`;
        }
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options,
        });
        if (error)
            return res.status(400).json({ error: error.message });
        // set cookies if session present (depends on email confirmation settings)
        if (data.session) {
            const maxAge = remember ? 60 * 60 * 24 * 60 : undefined; // 60 days
            res.cookie(env_1.env.ACCESS_COOKIE_NAME, data.session.access_token, {
                httpOnly: true,
                sameSite: 'lax',
                secure: process.env.NODE_ENV === 'production',
                maxAge,
            });
            res.cookie(env_1.env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
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
        if (!parse.success)
            return res.status(400).json({ error: parse.error.flatten() });
        const { email, password, remember } = parse.data;
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error)
            return res.status(401).json({ error: error.message });
        const maxAge = remember ? 60 * 60 * 24 * 60 : undefined; // 60 days
        res.cookie(env_1.env.ACCESS_COOKIE_NAME, data.session.access_token, {
            httpOnly: true,
            sameSite: 'lax',
            secure: process.env.NODE_ENV === 'production',
            maxAge,
        });
        res.cookie(env_1.env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
            httpOnly: true,
            sameSite: 'lax',
            secure: process.env.NODE_ENV === 'production',
            maxAge,
        });
        return res.json({ user: data.user });
    });
    router.post('/signout', async (_req, res) => {
        res.clearCookie(env_1.env.ACCESS_COOKIE_NAME);
        res.clearCookie(env_1.env.REFRESH_COOKIE_NAME);
        return res.status(204).send();
    });
    // Sets cookies from tokens coming from email link
    router.post('/set-session', async (req, res) => {
        const schema = zod_1.z.object({
            access_token: zod_1.z.string(),
            refresh_token: zod_1.z.string(),
            remember: zod_1.z.boolean().optional().default(false),
        });
        const parsed = schema.safeParse(req.body);
        if (!parsed.success)
            return res.status(400).json({ error: parsed.error.flatten() });
        const { access_token, refresh_token, remember } = parsed.data;
        // Validate tokens by fetching user
        const { data, error } = await supabase.auth.getUser(access_token);
        if (error || !data.user)
            return res.status(401).json({ error: 'Invalid tokens' });
        const maxAge = remember ? 60 * 60 * 24 * 60 : undefined;
        res.cookie(env_1.env.ACCESS_COOKIE_NAME, access_token, {
            httpOnly: true,
            sameSite: 'lax',
            secure: process.env.NODE_ENV === 'production',
            maxAge,
        });
        res.cookie(env_1.env.REFRESH_COOKIE_NAME, refresh_token, {
            httpOnly: true,
            sameSite: 'lax',
            secure: process.env.NODE_ENV === 'production',
            maxAge,
        });
        return res.status(200).json({ ok: true });
    });
    return router;
}
//# sourceMappingURL=auth.js.map