import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { createClient } from '@supabase/supabase-js';
import { env } from './shared/env';
import { buildAuthRouter } from './shared/routes/auth';
import { authMiddleware } from './shared/middleware/authMiddleware';

const app = express();

app.use(helmet());
app.use(express.json());
app.use(cookieParser());
app.use(
  cors({
    origin: env.CORS_ORIGIN ?? true,
    credentials: true,
  })
);

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  auth: {
    persistSession: false,
    detectSessionInUrl: false,
  },
});

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.use('/auth', buildAuthRouter({ supabase }));

app.get('/me', authMiddleware({ supabase }), async (req, res) => {
  res.set({
    'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, private',
    'Pragma': 'no-cache',
    'Expires': '0',
    'Surrogate-Control': 'no-store',
    'Vary': 'Cookie, Origin',
  });
  const authUser = (req as any).user;
  
  const { data: userData, error } = await supabase
    .from('users')
    .select('id, email, username, created_at, updated_at')
    .eq('id', authUser.id)
    .single();

  if (error) {
    console.error('Error fetching user data:', error);
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

app.get('/qbank/summary', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const { data, error } = await supabase.rpc('get_user_totals', { p_user_id: authUser.id });
  if (error) return res.status(500).json({ error: error.message });
  res.set({ 'Cache-Control': 'private, max-age=15' });
  res.json({ summary: data && data[0] ? data[0] : { total_answered: 0, correct: 0, accuracy_pct: null, avg_time_ms: null, last_attempt_at: null } });
});

app.get('/qbank/topics', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const limit = Math.min(parseInt((req.query.limit as string) || '50', 10), 200);
  const offset = Math.max(parseInt((req.query.offset as string) || '0', 10), 0);
  const { data, error } = await supabase.rpc('get_user_topic_cards', { p_user_id: authUser.id, p_limit: limit, p_offset: offset });
  if (error) return res.status(500).json({ error: error.message });
  res.set({ 'Cache-Control': 'private, max-age=15' });
  res.json({ topics: data ?? [] });
});

app.get('/qbank/specialties', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const { data, error } = await supabase.rpc('get_user_specialty_cards', { p_user_id: authUser.id });
  if (error) return res.status(500).json({ error: error.message });
  res.set({ 'Cache-Control': 'private, max-age=15' });
  res.json({ specialties: data ?? [] });
});

app.get('/qbank/practice/next', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const specialtyId = req.query.specialty_id as string;
  if (!specialtyId) return res.status(400).json({ error: 'specialty_id is required' });

  const { data: qData, error: qErr } = await supabase
    .from('questions')
    .select('id, topic_id, type, stem, explanation_l1, explanation_l2, difficulty, time_limit_sec, topics!inner(specialty_id, name)')
    .eq('topics.specialty_id', specialtyId)
    .eq('is_active', true)
    .limit(50);

  if (qErr) return res.status(500).json({ error: qErr.message });
  const { data: attempts, error: aErr } = await supabase
    .from('user_question_attempts')
    .select('question_id')
    .eq('user_id', authUser.id);
  if (aErr) return res.status(500).json({ error: aErr.message });
  const attemptedIds = new Set((attempts ?? []).map((a: any) => a.question_id));
  const available = (qData ?? []).filter((q: any) => !attemptedIds.has(q.id));
  const chosen = available.length > 0 ? available[Math.floor(Math.random() * available.length)] : (qData ?? [])[Math.floor(Math.random() * (qData?.length || 1))];
  if (!chosen) return res.json({ question: null, options: [], progress: { completed: 0, total: 0 } });

  const { data: options, error: oErr } = await supabase
    .from('mcq_options')
    .select('id, label, body')
    .eq('question_id', chosen.id)
    .order('label', { ascending: true });
  if (oErr) return res.status(500).json({ error: oErr.message });

  const { data: prog, error: pErr } = await supabase
    .from('user_question_attempts')
    .select('question_id, questions!inner(topics!inner(specialty_id))')
    .eq('user_id', authUser.id)
    .eq('questions.topics.specialty_id', specialtyId);
  if (pErr) return res.status(500).json({ error: pErr.message });

  const total = qData?.length || 0;
  const completed = prog?.length || 0;

  res.json({
    question: {
      id: chosen.id,
      type: chosen.type,
      stem: chosen.stem,
      difficulty: chosen.difficulty,
      time_limit_sec: chosen.time_limit_sec,
      topic_name: (chosen as any).topics?.name || 'Unknown Topic',
    },
    options: options ?? [],
    progress: { completed, total },
  });
});

app.post('/qbank/practice/answer', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const { question_id, selected_option_id, text_answer, time_taken_ms, confidence } = req.body || {};
  if (!question_id) return res.status(400).json({ error: 'question_id is required' });

  const { data: q, error: qErr } = await supabase
    .from('questions')
    .select('*')
    .eq('id', question_id)
    .single();
  
  console.log('Question data from DB:', q);
  console.log('Available fields:', Object.keys(q || {}));
  
  if (qErr || !q) return res.status(404).json({ error: 'Question not found' });

  let is_correct = false;
  if (q.type === 'MCQ') {
    if (!selected_option_id) return res.status(400).json({ error: 'selected_option_id required for MCQ' });
    const { data: opt, error: optErr } = await supabase
      .from('mcq_options')
      .select('id, is_correct')
      .eq('id', selected_option_id)
      .eq('question_id', question_id)
      .single();
    if (optErr || !opt) return res.status(400).json({ error: 'Invalid option' });
    is_correct = !!opt.is_correct;
    const { data: correctOpt } = await supabase
      .from('mcq_options')
      .select('label, body')
      .eq('question_id', question_id)
      .eq('is_correct', true)
      .single();
    (req as any).correct_option = correctOpt || null;
  } else {
    if (!text_answer) return res.status(400).json({ error: 'text_answer required for SAQ' });
    const { data: keys, error: kErr } = await supabase
      .from('saq_answer_keys')
      .select('match_type, pattern, case_sensitive')
      .eq('question_id', question_id);
    if (kErr) return res.status(500).json({ error: kErr.message });
    const answer = String(text_answer || '');
    is_correct = (keys || []).some((k: any) => {
      const a = k.case_sensitive ? answer : answer.toLowerCase();
      const p = k.case_sensitive ? k.pattern : String(k.pattern || '').toLowerCase();
      if (k.match_type === 'exact') return a === p;
      if (k.match_type === 'contains') return a.includes(p);
      if (k.match_type === 'regex') {
        try { return new RegExp(k.pattern, k.case_sensitive ? '' : 'i').test(answer); } catch { return false; }
      }
      return false;
    });
  }

  const insertPayload: any = {
    user_id: authUser.id,
    question_id,
    selected_option_id: selected_option_id ?? null,
    text_answer: text_answer ?? null,
    is_correct,
    time_taken_ms: time_taken_ms ?? null,
    confidence: confidence ?? null,
    guessed: null,
  };
  const { error: insErr } = await supabase.from('user_question_attempts').insert(insertPayload);
  if (insErr) return res.status(500).json({ error: insErr.message });

  res.json({
    is_correct,
    correct_option: (req as any).correct_option || null,
    explanations: {
      quick: q.explanation_l1,
      quick_points: q.explanation_l1_points || null,
      detailed: q.explanation_l2 || null,
      detailed_context: q.detailed_context || null,
      detailed_pathophysiology: q.detailed_pathophysiology || null,
      eli5: q.explanation_eli5 || null,
      visual: null,
    },
  });
});

app.listen(env.PORT, () => {
  console.log(`API listening on http://localhost:${env.PORT}`);
});


