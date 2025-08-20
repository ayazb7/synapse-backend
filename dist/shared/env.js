"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.env = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
const zod_1 = require("zod");
dotenv_1.default.config();
const EnvSchema = zod_1.z.object({
    PORT: zod_1.z.string().default('4000').transform((v) => parseInt(v, 10)),
    SUPABASE_URL: zod_1.z.string().url(),
    SUPABASE_ANON_KEY: zod_1.z.string().min(1),
    SUPABASE_SERVICE_ROLE_KEY: zod_1.z.string().optional(),
    CORS_ORIGIN: zod_1.z.string().optional(),
    ACCESS_COOKIE_NAME: zod_1.z.string().default('sb-access-token'),
    REFRESH_COOKIE_NAME: zod_1.z.string().default('sb-refresh-token'),
    FRONTEND_URL: zod_1.z.string().url().optional(),
    COOKIE_SAMESITE: zod_1.z
        .enum(['lax', 'strict', 'none'])
        .optional()
        .default('lax'),
});
const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
    console.error('Invalid environment variables:', parsed.error.flatten().fieldErrors);
    process.exit(1);
}
exports.env = parsed.data;
//# sourceMappingURL=env.js.map