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
    res.set({
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, private',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Surrogate-Control': 'no-store',
        'Vary': 'Cookie, Origin',
    });
    const authUser = req.user;
    const { data: userData, error } = await exports.supabase
        .from('users')
        .select('id, email, username, created_at, updated_at')
        .eq('id', authUser.id)
        .single();
    if (error) {
        console.error('Error fetching user data:', error);
        // If user doesn't exist in users table, create one or return auth user data
        if (error.code === 'PGRST116') {
            // No user found, return basic auth user data
            const user = {
                ...authUser,
                username: authUser.user_metadata?.username || authUser.email?.split('@')[0] || 'User'
            };
            return res.json({ user });
        }
        return res.status(500).json({ error: 'Failed to fetch user data' });
    }
    const user = {
        ...authUser,
        email: userData.email,
        username: userData.username,
        created_at: userData.created_at,
        updated_at: userData.updated_at
    };
    res.json({ user });
});
app.get('/qbank/summary', (0, authMiddleware_1.authMiddleware)({ supabase: exports.supabase }), async (req, res) => {
    const authUser = req.user;
    const { data, error } = await exports.supabase.rpc('get_user_totals', { p_user_id: authUser.id });
    if (error)
        return res.status(500).json({ error: error.message });
    res.set({ 'Cache-Control': 'private, max-age=15' });
    res.json({ summary: data && data[0] ? data[0] : { total_answered: 0, correct: 0, accuracy_pct: null, avg_time_ms: null, last_attempt_at: null } });
});
app.get('/qbank/topics', (0, authMiddleware_1.authMiddleware)({ supabase: exports.supabase }), async (req, res) => {
    const authUser = req.user;
    const limit = Math.min(parseInt(req.query.limit || '50', 10), 200);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
    const { data, error } = await exports.supabase.rpc('get_user_topic_cards', { p_user_id: authUser.id, p_limit: limit, p_offset: offset });
    if (error)
        return res.status(500).json({ error: error.message });
    res.set({ 'Cache-Control': 'private, max-age=15' });
    res.json({ topics: data ?? [] });
});
app.get('/qbank/specialties', (0, authMiddleware_1.authMiddleware)({ supabase: exports.supabase }), async (req, res) => {
    const authUser = req.user;
    const { data, error } = await exports.supabase.rpc('get_user_specialty_cards', { p_user_id: authUser.id });
    if (error)
        return res.status(500).json({ error: error.message });
    res.set({ 'Cache-Control': 'private, max-age=15' });
    res.json({ specialties: data ?? [] });
});
app.get('/qbank/practice/next', (0, authMiddleware_1.authMiddleware)({ supabase: exports.supabase }), async (req, res) => {
    const authUser = req.user;
    const specialtyId = req.query.specialty_id;
    if (!specialtyId)
        return res.status(400).json({ error: 'specialty_id is required' });
    const { data: qData, error: qErr } = await exports.supabase
        .from('questions')
        .select('id, topic_id, type, stem, options, explanation_l1_points, explanation_l2, topics!inner(specialty_id, name)')
        .eq('topics.specialty_id', specialtyId)
        .eq('is_active', true)
        .limit(50);
    if (qErr)
        return res.status(500).json({ error: qErr.message });
    const { data: attempts, error: aErr } = await exports.supabase
        .from('user_question_attempts')
        .select('question_id')
        .eq('user_id', authUser.id);
    if (aErr)
        return res.status(500).json({ error: aErr.message });
    const attemptedIds = new Set((attempts ?? []).map((a) => a.question_id));
    const available = (qData ?? []).filter((q) => !attemptedIds.has(q.id));
    const chosen = available.length > 0 ? available[Math.floor(Math.random() * available.length)] : (qData ?? [])[Math.floor(Math.random() * (qData?.length || 1))];
    if (!chosen)
        return res.json({ question: null, options: [], progress: { completed: 0, total: 0 } });
    let formattedOptions = [];
    if (chosen.type === 'MCQ' && chosen.options) {
        const optionsArray = Array.isArray(chosen.options) ? chosen.options : JSON.parse(chosen.options);
        formattedOptions = optionsArray.map((option, index) => ({
            id: index,
            label: String.fromCharCode(65 + index),
            body: option
        }));
    }
    const { data: prog, error: pErr } = await exports.supabase
        .from('user_question_attempts')
        .select('question_id, questions!inner(topics!inner(specialty_id))')
        .eq('user_id', authUser.id)
        .eq('questions.topics.specialty_id', specialtyId);
    if (pErr)
        return res.status(500).json({ error: pErr.message });
    const total = qData?.length || 0;
    const completed = prog?.length || 0;
    res.json({
        question: {
            id: chosen.id,
            type: chosen.type,
            stem: chosen.stem,
            topic_name: chosen.topics?.name || 'Unknown Topic',
        },
        options: formattedOptions,
        progress: { completed, total },
    });
});
app.post('/qbank/practice/answer', (0, authMiddleware_1.authMiddleware)({ supabase: exports.supabase }), async (req, res) => {
    try {
        console.log('=== /qbank/practice/answer REQUEST ===');
        const authUser = req.user;
        const { question_id, selected_option_id, text_answer, time_taken_ms, confidence } = req.body || {};
        console.log('Request body:', req.body);
        console.log('Auth user ID:', authUser?.id);
        console.log('Question ID:', question_id);
        console.log('Selected option ID:', selected_option_id);
        console.log('Text answer:', text_answer);
        if (!question_id)
            return res.status(400).json({ error: 'question_id is required' });
        console.log('Fetching question from database...');
        const { data: q, error: qErr } = await exports.supabase
            .from('questions')
            .select('id, type, options, correct_answer, explanation_l1_points, explanation_l2, explanation_eli5')
            .eq('id', question_id)
            .single();
        console.log('Question fetch result:', { data: q, error: qErr });
        if (qErr) {
            console.error('Error fetching question:', qErr);
            return res.status(500).json({ error: 'Failed to fetch question' });
        }
        if (!q) {
            console.error('No question found for ID:', question_id);
            return res.status(404).json({ error: 'Question not found' });
        }
        console.log('Question data:', {
            id: q.id,
            type: q.type,
            correct_answer: q.correct_answer,
            explanation_l1_points: q.explanation_l1_points,
            explanation_l2: q.explanation_l2,
            explanation_eli5: q.explanation_eli5
        });
        console.log('Processing answer validation...');
        let is_correct = false;
        if (q.type === 'MCQ') {
            console.log('Processing MCQ answer...');
            if (selected_option_id === undefined || selected_option_id === null)
                return res.status(400).json({ error: 'selected_option_id required for MCQ' });
            console.log('Raw options from DB:', q.options);
            const optionsArray = Array.isArray(q.options) ? q.options : JSON.parse(q.options || '[]');
            console.log('Parsed options array:', optionsArray);
            if (selected_option_id < 0 || selected_option_id >= optionsArray.length) {
                console.log('Invalid option index:', selected_option_id, 'Array length:', optionsArray.length);
                return res.status(400).json({ error: 'Invalid option index' });
            }
            // Check if answer is correct
            is_correct = selected_option_id === q.correct_answer;
            console.log('Answer check: selected =', selected_option_id, 'correct =', q.correct_answer, 'is_correct =', is_correct);
            // Set correct option for response
            const correctOption = {
                id: q.correct_answer,
                label: String.fromCharCode(65 + q.correct_answer), // A, B, C, D, etc.
                body: optionsArray[q.correct_answer]
            };
            console.log('Correct option:', correctOption);
            req.correct_option = correctOption;
        }
        else {
            if (!text_answer)
                return res.status(400).json({ error: 'text_answer required for SAQ' });
            const { data: keys, error: kErr } = await exports.supabase
                .from('saq_answer_keys')
                .select('match_type, pattern, case_sensitive')
                .eq('question_id', question_id);
            if (kErr)
                return res.status(500).json({ error: kErr.message });
            const answer = String(text_answer || '');
            is_correct = (keys || []).some((k) => {
                const a = k.case_sensitive ? answer : answer.toLowerCase();
                const p = k.case_sensitive ? k.pattern : String(k.pattern || '').toLowerCase();
                if (k.match_type === 'exact')
                    return a === p;
                if (k.match_type === 'contains')
                    return a.includes(p);
                if (k.match_type === 'regex') {
                    try {
                        return new RegExp(k.pattern, k.case_sensitive ? '' : 'i').test(answer);
                    }
                    catch {
                        return false;
                    }
                }
                return false;
            });
        }
        const insertPayload = {
            user_id: authUser.id,
            question_id,
            selected_option_id: selected_option_id ?? null,
            text_answer: text_answer ?? null,
            is_correct,
            time_taken_ms: time_taken_ms ?? null,
            confidence: confidence ?? null,
            guessed: null,
        };
        const { error: insErr } = await exports.supabase.from('user_question_attempts').insert(insertPayload);
        if (insErr)
            return res.status(500).json({ error: insErr.message });
        console.log('Processing explanations...');
        let quickPoints = null;
        if (q.explanation_l1_points) {
            console.log('Raw explanation_l1_points:', q.explanation_l1_points);
            console.log('Type of explanation_l1_points:', typeof q.explanation_l1_points);
            try {
                quickPoints = Array.isArray(q.explanation_l1_points)
                    ? q.explanation_l1_points
                    : JSON.parse(q.explanation_l1_points);
                console.log('Parsed quick points:', quickPoints);
            }
            catch (e) {
                console.warn('Failed to parse explanation_l1_points:', e);
                quickPoints = null;
            }
        }
        else {
            console.log('No explanation_l1_points found in question data');
        }
        const responseData = {
            is_correct,
            correct_option: req.correct_option || null,
            explanations: {
                quick_points: quickPoints,
                detailed: q.explanation_l2 || null,
                eli5: q.explanation_eli5 || null,
                visual: null,
            },
        };
        console.log('=== RESPONSE DATA ===');
        console.log('Full response:', JSON.stringify(responseData, null, 2));
        res.json(responseData);
    }
    catch (error) {
        console.error('Error in /qbank/practice/answer:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
app.listen(env_1.env.PORT, () => {
    console.log(`API listening on http://localhost:${env_1.env.PORT}`);
});
//# sourceMappingURL=server.js.map