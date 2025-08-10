"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.supabase = void 0;
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const cookie_parser_1 = __importDefault(require("cookie-parser"));
const supabase_js_1 = require("@supabase/supabase-js");
const env_1 = require("./shared/env");
const auth_1 = require("./shared/routes/auth");
const authMiddleware_1 = require("./shared/middleware/authMiddleware");
const app = (0, express_1.default)();
app.use((0, helmet_1.default)());
app.use(express_1.default.json());
app.use((0, cookie_parser_1.default)());
app.use((0, cors_1.default)({
    origin: env_1.env.CORS_ORIGIN ?? true,
    credentials: true,
}));
exports.supabase = (0, supabase_js_1.createClient)(env_1.env.SUPABASE_URL, env_1.env.SUPABASE_ANON_KEY, {
    auth: {
        persistSession: false,
        detectSessionInUrl: false,
    },
});
app.get('/health', (_req, res) => {
    res.json({ ok: true });
});
app.use('/auth', (0, auth_1.buildAuthRouter)({ supabase: exports.supabase }));
app.get('/me', (0, authMiddleware_1.authMiddleware)({ supabase: exports.supabase }), async (req, res) => {
    const user = req.user;
    res.json({ user });
});
app.listen(env_1.env.PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`API listening on http://localhost:${env_1.env.PORT}`);
});
//# sourceMappingURL=server.js.map