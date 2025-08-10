"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authMiddleware = authMiddleware;
const env_1 = require("../env");
function authMiddleware({ supabase }) {
    return async function ensureAuth(req, res, next) {
        const accessToken = req.cookies?.[env_1.env.ACCESS_COOKIE_NAME];
        if (!accessToken)
            return res.status(401).json({ error: 'Not authenticated' });
        const { data, error } = await supabase.auth.getUser(accessToken);
        if (error || !data.user)
            return res.status(401).json({ error: 'Invalid session' });
        req.user = data.user;
        next();
    };
}
//# sourceMappingURL=authMiddleware.js.map