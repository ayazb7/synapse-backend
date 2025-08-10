"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildAuthRouter = buildAuthRouter;
const express_1 = require("express");
const zod_1 = require("zod");
const env_1 = require("../env");
const SignupSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(6),
    full_name: zod_1.z.string().min(1),
});
const SigninSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(6),
});
function buildAuthRouter({ supabase }) {
    const router = (0, express_1.Router)();
    router.post('/signup', async (req, res) => {
        const parse = SignupSchema.safeParse(req.body);
        if (!parse.success)
            return res.status(400).json({ error: parse.error.flatten() });
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
        if (error)
            return res.status(400).json({ error: error.message });
        // set cookies if session present (depends on email confirmation settings)
        if (data.session) {
            res.cookie(env_1.env.ACCESS_COOKIE_NAME, data.session.access_token, {
                httpOnly: true,
                sameSite: 'lax',
                secure: process.env.NODE_ENV === 'production',
            });
            res.cookie(env_1.env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
                httpOnly: true,
                sameSite: 'lax',
                secure: process.env.NODE_ENV === 'production',
            });
        }
        return res.status(201).json({ user: data.user });
    });
    router.post('/signin', async (req, res) => {
        const parse = SigninSchema.safeParse(req.body);
        if (!parse.success)
            return res.status(400).json({ error: parse.error.flatten() });
        const { email, password } = parse.data;
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error)
            return res.status(401).json({ error: error.message });
        res.cookie(env_1.env.ACCESS_COOKIE_NAME, data.session.access_token, {
            httpOnly: true,
            sameSite: 'lax',
            secure: process.env.NODE_ENV === 'production',
        });
        res.cookie(env_1.env.REFRESH_COOKIE_NAME, data.session.refresh_token, {
            httpOnly: true,
            sameSite: 'lax',
            secure: process.env.NODE_ENV === 'production',
        });
        return res.json({ user: data.user });
    });
    router.post('/signout', async (_req, res) => {
        res.clearCookie(env_1.env.ACCESS_COOKIE_NAME);
        res.clearCookie(env_1.env.REFRESH_COOKIE_NAME);
        return res.status(204).send();
    });
    return router;
}
//# sourceMappingURL=auth.js.map