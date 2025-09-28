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
    origin: function (origin, callback) {
      // Allow requests with no origin (like mobile apps or curl requests)
      if (!origin) return callback(null, true);
      
      if (env.CORS_ORIGIN) {
        // In production, check against allowed origins
        const allowedOrigins = env.CORS_ORIGIN.split(',').map(o => o.trim());
        if (allowedOrigins.includes(origin)) {
          return callback(null, true);
        } else {
          return callback(new Error('Not allowed by CORS'));
        }
      } else {
        // In development, allow all origins
        return callback(null, true);
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Cookie'],
  })
);

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  auth: {
    persistSession: false,
    detectSessionInUrl: false,
  },
});

// Admin client for server-side operations that bypass RLS
export const supabaseAdmin = createClient(
  env.SUPABASE_URL, 
  env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_ANON_KEY,
  {
    auth: {
      persistSession: false,
      detectSessionInUrl: false,
    },
  }
);

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.use('/auth', buildAuthRouter({ supabase }));

app.get('/me', authMiddleware({ supabase }), async (req, res) => {
  try {
    res.set({
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, private',
      'Pragma': 'no-cache',
      'Expires': '0',
      'Surrogate-Control': 'no-store',
      'Vary': 'Cookie, Origin',
    });
    
    const authUser = (req as any).user;
    console.log('Auth user from middleware:', authUser?.id);
    
    if (!authUser || !authUser.id) {
      console.error('No auth user found in request');
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    const { data: userData, error } = await supabase
      .from('users')
      .select('id, email, username, created_at, updated_at')
      .eq('id', authUser.id)
      .single();

    if (error) {
      console.error('Error fetching user data:', error);
      // If user doesn't exist in users table, create one or return auth user data
      if (error.code === 'PGRST116') {
        console.log('User not found in users table, returning auth user data');
        // No user found, return basic auth user data
        const user = {
          id: authUser.id,
          email: authUser.email,
          username: authUser.user_metadata?.username || authUser.email?.split('@')[0] || 'User',
          created_at: authUser.created_at,
          updated_at: authUser.updated_at
        };
        return res.json({ user });
      }
      return res.status(500).json({ error: 'Failed to fetch user data' });
    }

    const user = {
      id: authUser.id,
      email: userData.email || authUser.email,
      username: userData.username || authUser.user_metadata?.username || authUser.email?.split('@')[0] || 'User',
      created_at: userData.created_at || authUser.created_at,
      updated_at: userData.updated_at || authUser.updated_at
    };

    console.log('Returning user data:', { id: user.id, email: user.email });
    res.json({ user });
  } catch (error) {
    console.error('Unexpected error in /me endpoint:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
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

app.get('/qbank/specialty/:specialtyId/topics', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const { specialtyId } = req.params;
  
  if (!specialtyId) {
    return res.status(400).json({ error: 'specialty_id is required' });
  }

  // Get topics for this specialty with question counts
  const { data, error } = await supabase
    .from('topics')
    .select(`
      id,
      name,
      specialty_id,
      questions!inner(id)
    `)
    .eq('specialty_id', specialtyId)
    .eq('questions.is_active', true);

  if (error) {
    console.error('Error fetching topics:', error);
    return res.status(500).json({ error: error.message });
  }

  // Transform the data to include question counts
  const topics = (data || []).map(topic => ({
    id: topic.id,
    name: topic.name,
    specialty_id: topic.specialty_id,
    question_count: topic.questions?.length || 0
  }));

  res.set({ 'Cache-Control': 'private, max-age=30' });
  res.json({ topics });
});

// ==== Textbook API ====
// Outline: specialties -> topics -> page -> top-level sections
app.get('/textbook/outline', authMiddleware({ supabase }), async (_req, res) => {
  try {
    const { data, error } = await supabase
      .from('v_textbook_outline')
      .select('*');
    if (error) return res.status(500).json({ error: error.message });

    // Group by specialty and topic for frontend convenience
    const map: any = {};
    for (const row of data || []) {
      const sId = row.specialty_id;
      if (!map[sId]) {
        map[sId] = {
          specialty_id: row.specialty_id,
          specialty_name: row.specialty_name,
          specialty_slug: row.specialty_slug,
          topics: {},
        };
      }
      const tId = row.topic_id;
      if (!map[sId].topics[tId]) {
        map[sId].topics[tId] = {
          topic_id: row.topic_id,
          topic_name: row.topic_name,
          topic_slug: row.topic_slug,
          page: row.page_id ? {
            page_id: row.page_id,
            page_title: row.page_title,
            page_slug: row.page_slug,
            page_status: row.page_status,
            sections: [],
          } : null,
        };
      }
      if (row.section_id && map[sId].topics[tId].page) {
        map[sId].topics[tId].page.sections.push({
          section_id: row.section_id,
          title: row.section_title,
          anchor: row.section_anchor,
          section_type: row.section_type,
          position: row.section_position,
        });
      }
    }

    const specialties = Object.values(map).map((s: any) => ({
      ...s,
      topics: Object.values(s.topics),
    }));

    res.set({ 'Cache-Control': 'private, max-age=15' });
    res.json({ specialties });
  } catch (e: any) {
    res.status(500).json({ error: e?.message || 'Failed to load outline' });
  }
});

// Get all topics for a specialty with textbook pages
app.get('/textbook/specialty/:slug', authMiddleware({ supabase }), async (req, res) => {
  const { slug } = req.params as { slug: string };
  // Find specialty by slug
  const { data: spec, error: sErr } = await supabase
    .from('specialties')
    .select('id, name, slug, icon_name, icon_color, icon_bg_start, icon_bg_end')
    .eq('slug', slug)
    .single();
  if (sErr) return res.status(404).json({ error: 'Specialty not found' });

  const { data: topics, error } = await supabase
    .from('topics')
    .select('id, name, slug, description, textbook_pages(id, title, slug, status)')
    .eq('specialty_id', spec.id)
    .order('name');
  if (error) return res.status(500).json({ error: error.message });

  const normalized = (topics || []).map((t: any) => ({
    ...t,
    has_page: Array.isArray(t.textbook_pages) ? t.textbook_pages.length > 0 : !!t.textbook_pages,
  }));

  res.json({ specialty: spec, topics: normalized });
});

// Page content for a topic by slug
app.get('/textbook/:topicSlug', authMiddleware({ supabase }), async (req, res) => {
  const { topicSlug } = req.params as { topicSlug: string };
  // Locate topic and page
  const { data: topic, error: tErr } = await supabase
    .from('topics')
    .select('id, name, slug, specialty_id, specialties:specialty_id(name, slug)')
    .eq('slug', topicSlug)
    .single();
  if (tErr) return res.status(404).json({ error: 'Topic not found' });

  const { data: page, error: pErr } = await supabase
    .from('textbook_pages')
    .select('id, title, slug, summary, status')
    .eq('topic_id', (topic as any).id)
    .single();
  if (pErr) return res.status(404).json({ error: 'Textbook page not found' });

  // Sections and blocks
  const { data: sections, error: sErr2 } = await supabase
    .from('textbook_sections')
    .select('id, parent_section_id, title, anchor_slug, section_type, position')
    .eq('page_id', page.id)
    .order('position');
  if (sErr2) return res.status(500).json({ error: sErr2.message });

  const sectionIds = (sections || []).map((s: any) => s.id);
  let blocks: any[] = [];
  if (sectionIds.length > 0) {
    const { data: bData, error: bErr } = await supabase
      .from('textbook_blocks')
      .select('id, section_id, block_type, position, content, data')
      .in('section_id', sectionIds)
      .order('position');
    if (bErr) return res.status(500).json({ error: bErr.message });
    blocks = bData || [];
  }

  const { data: citations, error: cErr } = await supabase
    .from('textbook_citations')
    .select('id, section_id, citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position')
    .eq('page_id', page.id)
    .order('position');
  if (cErr) return res.status(500).json({ error: cErr.message });

  const { data: tags } = await supabase
    .from('textbook_page_tags')
    .select('tag')
    .eq('page_id', page.id);

  res.set({ 'Cache-Control': 'private, max-age=30' });
  res.json({ topic, page, sections: sections || [], blocks, citations: citations || [], tags: (tags || []).map((t: any) => t.tag) });
});

app.get('/qbank/practice/session', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const specialtyId = req.query.specialty_id as string;
  const topicIds = req.query.topic_ids as string; // comma-separated topic IDs
  const numQuestions = parseInt(req.query.num_questions as string || '25');
  
  if (!specialtyId) return res.status(400).json({ error: 'specialty_id is required' });
  if (!numQuestions || numQuestions < 1) return res.status(400).json({ error: 'num_questions must be a positive integer' });

  console.log('Loading practice session:', { specialtyId, topicIds, numQuestions });

  // Build the query
  let query = supabase
    .from('questions')
    .select('id, topic_id, type, stem, options, correct_answer, explanation_l1_points, explanation_points_by_option, explanation_l2, explanation_eli5, topics!inner(specialty_id, name)')
    .eq('topics.specialty_id', specialtyId)
    .eq('is_active', true);

  // Filter by specific topics if provided
  if (topicIds && topicIds.trim()) {
    const topicIdArray = topicIds.split(',').map(id => id.trim()).filter(Boolean);
    if (topicIdArray.length > 0) {
      query = query.in('topic_id', topicIdArray);
    }
  }

  const { data: allQuestions, error: qErr } = await query.limit(500);

  if (qErr) return res.status(500).json({ error: qErr.message });
  
  if (!allQuestions || allQuestions.length === 0) {
    return res.json({ questions: [], total_available: 0 });
  }

  // Get user's attempted questions to prioritize unattempted ones
  const { data: attempts, error: aErr } = await supabaseAdmin
    .from('user_question_attempts')
    .select('question_id')
    .eq('user_id', authUser.id);
  if (aErr) return res.status(500).json({ error: aErr.message });
  
  const attemptedIds = new Set((attempts ?? []).map((a: any) => a.question_id));
  const unattempted = allQuestions.filter((q: any) => !attemptedIds.has(q.id));
  const attempted = allQuestions.filter((q: any) => attemptedIds.has(q.id));

  // Shuffle and select questions (prioritize unattempted)
  const shuffleArray = (array: any[]) => {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  };

  const shuffledUnattempted = shuffleArray(unattempted);
  const shuffledAttempted = shuffleArray(attempted);
  const selectedQuestions = [...shuffledUnattempted, ...shuffledAttempted].slice(0, numQuestions);

  // Format questions with options and explanations
  const formattedQuestions = selectedQuestions.map((q: any) => {
    let formattedOptions = [];
    if (q.type === 'MCQ' && q.options) {
      const optionsArray = Array.isArray(q.options) ? q.options : JSON.parse(q.options);
      formattedOptions = optionsArray.map((option: string, index: number) => ({
        id: index,
        label: String.fromCharCode(65 + index),
        body: option
      }));
    }

    // Parse explanation_l1_points
    let quickPoints = null;
    if (q.explanation_l1_points) {
      try {
        quickPoints = Array.isArray(q.explanation_l1_points) 
          ? q.explanation_l1_points 
          : JSON.parse(q.explanation_l1_points);
      } catch (e) {
        console.warn('Failed to parse explanation_l1_points for question', q.id, ':', e);
        quickPoints = null;
      }
    }

    // Parse explanation_points_by_option
    let pointsByOption: any = null;
    const rawPbo = (q as any).explanation_points_by_option;
    if (rawPbo) {
      try {
        pointsByOption = typeof rawPbo === 'object' ? rawPbo : JSON.parse(rawPbo);
      } catch (e) {
        console.warn('Failed to parse explanation_points_by_option for question', q.id, ':', e);
        pointsByOption = null;
      }
    }

    return {
      id: q.id,
      type: q.type,
      stem: q.stem,
      topic_name: q.topics?.name || 'Unknown Topic',
      options: formattedOptions,
      correct_answer: q.correct_answer,
      explanations: {
        quick_points: quickPoints,
        points_by_option: pointsByOption,
        detailed: q.explanation_l2 || null,
        eli5: q.explanation_eli5 || null,
        visual: null,
      }
    };
  });

  console.log(`Loaded ${formattedQuestions.length} questions for session`);

  res.json({
    questions: formattedQuestions,
    total_available: allQuestions.length
  });
});

app.get('/qbank/practice/next', authMiddleware({ supabase }), async (req, res) => {
  const authUser = (req as any).user;
  const specialtyId = req.query.specialty_id as string;
  const topicIds = req.query.topic_ids as string; // comma-separated topic IDs
  
  if (!specialtyId) return res.status(400).json({ error: 'specialty_id is required' });

  // Build the query
  let query = supabase
    .from('questions')
    .select('id, topic_id, type, stem, options, explanation_l1_points, explanation_points_by_option, explanation_l2, topics!inner(specialty_id, name)')
    .eq('topics.specialty_id', specialtyId)
    .eq('is_active', true);

  // Filter by specific topics if provided
  if (topicIds && topicIds.trim()) {
    const topicIdArray = topicIds.split(',').map(id => id.trim()).filter(Boolean);
    if (topicIdArray.length > 0) {
      query = query.in('topic_id', topicIdArray);
    }
  }

  const { data: qData, error: qErr } = await query.limit(200);

  if (qErr) return res.status(500).json({ error: qErr.message });
  const { data: attempts, error: aErr } = await supabaseAdmin
    .from('user_question_attempts')
    .select('question_id')
    .eq('user_id', authUser.id);
  if (aErr) return res.status(500).json({ error: aErr.message });
  const attemptedIds = new Set((attempts ?? []).map((a: any) => a.question_id));
  const available = (qData ?? []).filter((q: any) => !attemptedIds.has(q.id));
  const chosen = available.length > 0 ? available[Math.floor(Math.random() * available.length)] : (qData ?? [])[Math.floor(Math.random() * (qData?.length || 1))];
  if (!chosen) return res.json({ question: null, options: [], progress: { completed: 0, total: 0 } });

  let formattedOptions = [];
  if (chosen.type === 'MCQ' && chosen.options) {
    const optionsArray = Array.isArray(chosen.options) ? chosen.options : JSON.parse(chosen.options);
    formattedOptions = optionsArray.map((option: string, index: number) => ({
      id: index,
      label: String.fromCharCode(65 + index),
      body: option
    }));
  }

  const { data: prog, error: pErr } = await supabaseAdmin
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
      topic_name: (chosen as any).topics?.name || 'Unknown Topic',
    },
    options: formattedOptions,
    progress: { completed, total },
  });
});

app.get('/reference-ranges', authMiddleware({ supabase }), async (_req, res) => {
  try {
    const [gRes, iRes] = await Promise.all([
      supabase.from('reference_range_groups').select('id, title, group_order').order('group_order', { ascending: true }),
      supabase.from('reference_range_items').select('group_id, analyte, unit, population, value_text, item_order').order('item_order', { ascending: true })
    ]);

    if (gRes.error) return res.status(500).json({ error: gRes.error.message });
    if (iRes.error) return res.status(500).json({ error: iRes.error.message });

    const groupIdToItems: Record<string, any[]> = {};
    for (const it of iRes.data || []) {
      const key = String(it.group_id);
      if (!groupIdToItems[key]) groupIdToItems[key] = [];
      groupIdToItems[key].push({ analyte: it.analyte, unit: it.unit, population: it.population, value_text: it.value_text });
    }

    const groups = (gRes.data || []).map((g: any) => ({ id: g.id, title: g.title, items: groupIdToItems[String(g.id)] || [] }));

    res.set({ 'Cache-Control': 'private, max-age=300' });
    res.json({ groups });
  } catch (e: any) {
    res.status(500).json({ error: e?.message || 'Failed to load reference ranges' });
  }
});

app.post('/qbank/practice/submit', authMiddleware({ supabase }), async (req, res) => {
  try {
    console.log('=== /qbank/practice/submit REQUEST ===');
    const authUser = (req as any).user;
    const { question_id, selected_option_id, text_answer, time_taken_ms, is_correct } = req.body || {};
    
    console.log('Request:', { question_id, selected_option_id, text_answer, is_correct });
    
    if (!question_id) return res.status(400).json({ error: 'question_id is required' });
    if (is_correct === undefined || is_correct === null) return res.status(400).json({ error: 'is_correct is required' });

    // Store the user's attempt
    const insertPayload: any = {
      user_id: authUser.id,
      question_id,
      selected_option_id: null, // Don't store UUID anymore, we use indexes
      text_answer: selected_option_id !== undefined ? selected_option_id?.toString() : (text_answer ?? null),
      is_correct,
      time_taken_ms: time_taken_ms ?? null,
      confidence: null,
      guessed: null,
    };
    
    console.log('Insert payload:', insertPayload);
    const { error: insErr } = await supabaseAdmin.from('user_question_attempts').insert(insertPayload);
    if (insErr) {
      console.error('Insert error:', insErr);
      return res.status(500).json({ error: insErr.message });
    }

    console.log('Successfully saved user attempt');
    
    res.json({ success: true });
  } catch (error) {
    console.error('Error in /qbank/practice/submit:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==== Question Discussions ====
// List comments for a question (flat list with optional parent_id). Sorted oldest first.
app.get('/qbank/questions/:questionId/comments', authMiddleware({ supabase }), async (req, res) => {
  try {
    const authUser = (req as any).user;
    const { questionId } = req.params as { questionId: string };
    if (!questionId) return res.status(400).json({ error: 'questionId is required' });

    const { data, error } = await supabaseAdmin.rpc('get_question_comments', { p_user_id: authUser.id, p_question_id: questionId });
    if (error) return res.status(500).json({ error: error.message });

    const comments = (data || []).map((c: any) => ({
      id: c.id,
      question_id: c.question_id,
      user: { id: c.user_id },
      parent_id: c.parent_id,
      content: c.content,
      created_at: c.created_at,
      updated_at: c.updated_at,
      like_count: c.like_count || 0,
      liked: !!c.liked,
      reply_count: c.reply_count || 0,
    }));

    res.set({ 'Cache-Control': 'private, max-age=5' });
    res.json({ comments });
  } catch (error) {
    console.error('Error fetching comments:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create a new comment for a question
app.post('/qbank/questions/:questionId/comments', authMiddleware({ supabase }), async (req, res) => {
  try {
    const authUser = (req as any).user;
    const { questionId } = req.params as { questionId: string };
    const { content, parent_id } = req.body || {};

    if (!questionId) return res.status(400).json({ error: 'questionId is required' });
    if (typeof content !== 'string' || content.trim().length === 0) {
      return res.status(400).json({ error: 'content is required' });
    }
    if (content.length > 4000) {
      return res.status(400).json({ error: 'content too long' });
    }

    const insertPayload: any = {
      question_id: questionId,
      user_id: authUser.id,
      content: content.trim(),
      parent_id: parent_id || null,
    };

    const { data, error } = await supabaseAdmin
      .from('question_comments')
      .insert(insertPayload)
      .select('id, question_id, user_id, parent_id, content, created_at, updated_at')
      .single();

    if (error) return res.status(500).json({ error: error.message });

    res.status(201).json({ comment: data });
  } catch (error) {
    console.error('Error creating comment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// List replies for a comment
app.get('/qbank/comments/:commentId/replies', authMiddleware({ supabase }), async (req, res) => {
  try {
    const authUser = (req as any).user;
    const { commentId } = req.params as { commentId: string };
    if (!commentId) return res.status(400).json({ error: 'commentId is required' });
    const { data, error } = await supabaseAdmin.rpc('get_comment_replies', { p_user_id: authUser.id, p_parent_id: commentId });
    if (error) return res.status(500).json({ error: error.message });
    const replies = (data || []).map((c: any) => ({
      id: c.id,
      question_id: c.question_id,
      user: { id: c.user_id },
      parent_id: c.parent_id,
      content: c.content,
      created_at: c.created_at,
      updated_at: c.updated_at,
      like_count: c.like_count || 0,
      liked: !!c.liked,
    }));
    res.json({ replies });
  } catch (error) {
    console.error('Error fetching replies:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Toggle like on a comment
app.post('/qbank/comments/:commentId/like', authMiddleware({ supabase }), async (req, res) => {
  try {
    const authUser = (req as any).user;
    const { commentId } = req.params as { commentId: string };
    if (!commentId) return res.status(400).json({ error: 'commentId is required' });

    // Try insert; if conflict, delete to toggle
    const { error: insErr } = await supabaseAdmin.from('question_comment_likes').insert({ user_id: authUser.id, comment_id: commentId });
    if (insErr && !String(insErr.message).includes('duplicate key')) {
      console.error('Like insert error:', insErr);
      return res.status(500).json({ error: insErr.message });
    }
    if (insErr) {
      // Already liked -> unlike
      const { error: delErr } = await supabaseAdmin.from('question_comment_likes').delete().eq('user_id', authUser.id).eq('comment_id', commentId);
      if (delErr) return res.status(500).json({ error: delErr.message });
      return res.json({ liked: false });
    }
    res.json({ liked: true });
  } catch (error) {
    console.error('Error toggling like:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(env.PORT, () => {
  console.log(`API listening on http://localhost:${env.PORT}`);
});


