CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1) Helper trigger to auto-update updated_at
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    CREATE OR REPLACE FUNCTION set_updated_at()
    RETURNS trigger AS $f$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END
    $f$ LANGUAGE plpgsql;
  END IF;
END$$;

-- 2) Enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'question_type') THEN
    CREATE TYPE question_type AS ENUM ('MCQ', 'SAQ');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'confidence_level') THEN
    CREATE TYPE confidence_level AS ENUM ('low', 'medium', 'high');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'saq_match_type') THEN
    CREATE TYPE saq_match_type AS ENUM ('exact', 'contains', 'regex');
  END IF;
END$$;

-- 3) Core taxonomy
CREATE TABLE IF NOT EXISTS specialties (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL UNIQUE,
  slug       text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS topics (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  specialty_id  uuid NOT NULL REFERENCES specialties(id) ON DELETE CASCADE,
  name          text NOT NULL,
  slug          text NOT NULL,
  description   text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (specialty_id, name),
  UNIQUE (specialty_id, slug)
);
CREATE INDEX IF NOT EXISTS topics_specialty_idx ON topics(specialty_id);

-- 4) Questions
CREATE TABLE IF NOT EXISTS questions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id        uuid NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  type            question_type NOT NULL,
  stem            text NOT NULL,
  explanation_l1  text,
  explanation_l2  text,
  media_url       text,
  difficulty      smallint CHECK (difficulty BETWEEN 1 AND 5),
  time_limit_sec  integer,
  is_active       boolean NOT NULL DEFAULT true,
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS questions_topic_idx  ON questions(topic_id);
CREATE INDEX IF NOT EXISTS questions_active_idx ON questions(is_active);

-- updated_at trigger for questions
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_questions_updated_at') THEN
    CREATE TRIGGER trg_questions_updated_at
    BEFORE UPDATE ON questions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END$$;

-- 5) MCQ options
CREATE TABLE IF NOT EXISTS mcq_options (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id  uuid NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  label        text NOT NULL CHECK (label IN ('A','B','C','D')),
  body         text NOT NULL,
  is_correct   boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX IF NOT EXISTS mcq_option_unique_label_per_question
  ON mcq_options(question_id, label);
CREATE INDEX IF NOT EXISTS mcq_options_question_idx ON mcq_options(question_id);

-- 6) SAQ acceptable answers/patterns
CREATE TABLE IF NOT EXISTS saq_answer_keys (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id    uuid NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  match_type     saq_match_type NOT NULL DEFAULT 'contains',
  pattern        text NOT NULL,
  case_sensitive boolean NOT NULL DEFAULT false,
  weight         real NOT NULL DEFAULT 1.0
);
CREATE INDEX IF NOT EXISTS saq_keys_question_idx ON saq_answer_keys(question_id);

-- 7) User attempts (for accuracy, avg time, streaks)
CREATE TABLE IF NOT EXISTS user_question_attempts (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id        uuid NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  selected_option_id uuid REFERENCES mcq_options(id) ON DELETE SET NULL,
  text_answer        text,
  is_correct         boolean NOT NULL,
  time_taken_ms      integer CHECK (time_taken_ms >= 0),
  confidence         confidence_level,
  guessed            boolean,
  attempted_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, question_id, attempted_at)
);
CREATE INDEX IF NOT EXISTS attempts_user_idx      ON user_question_attempts(user_id);
CREATE INDEX IF NOT EXISTS attempts_question_idx  ON user_question_attempts(question_id);
CREATE INDEX IF NOT EXISTS attempts_user_time_idx ON user_question_attempts(user_id, attempted_at DESC);

-- 8) Views for fast dashboard queries
CREATE OR REPLACE VIEW v_topic_question_counts AS
SELECT
  t.id          AS topic_id,
  t.name        AS topic_name,
  t.specialty_id,
  COUNT(q.id) FILTER (WHERE q.is_active) AS total_questions
FROM topics t
LEFT JOIN questions q
  ON q.topic_id = t.id AND q.is_active
GROUP BY t.id;

CREATE OR REPLACE VIEW v_user_topic_metrics AS
SELECT
  a.user_id,
  q.topic_id,
  COUNT(*)                             AS attempts,
  COUNT(*) FILTER (WHERE a.is_correct) AS correct,
  ROUND(100.0 *
    COUNT(*) FILTER (WHERE a.is_correct) / NULLIF(COUNT(*),0), 2) AS accuracy_pct,
  AVG(a.time_taken_ms)::int            AS avg_time_ms,
  MAX(a.attempted_at)                  AS last_attempt_at
FROM user_question_attempts a
JOIN questions q ON q.id = a.question_id
GROUP BY a.user_id, q.topic_id;

-- Adjust timezone as needed; UK audience uses Europe/London
CREATE OR REPLACE VIEW v_user_daily_attempts AS
SELECT
  user_id,
  (attempted_at AT TIME ZONE 'Europe/London')::date AS local_date,
  COUNT(*) AS attempts
FROM user_question_attempts
GROUP BY user_id, (attempted_at AT TIME ZONE 'Europe/London')::date
ORDER BY user_id, local_date;

-- 9) Row-Level Security (RLS)

-- Enable RLS
ALTER TABLE specialties            ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions              ENABLE ROW LEVEL SECURITY;
ALTER TABLE mcq_options            ENABLE ROW LEVEL SECURITY;
ALTER TABLE saq_answer_keys        ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_question_attempts ENABLE ROW LEVEL SECURITY;

-- Public READ for content/reference tables
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'specialties_read_all') THEN
    CREATE POLICY specialties_read_all ON specialties
      FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'topics_read_all') THEN
    CREATE POLICY topics_read_all ON topics
      FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'questions_read_all') THEN
    CREATE POLICY questions_read_all ON questions
      FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'mcq_options_read_all') THEN
    CREATE POLICY mcq_options_read_all ON mcq_options
      FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'saq_keys_read_all') THEN
    CREATE POLICY saq_keys_read_all ON saq_answer_keys
      FOR SELECT USING (true);
  END IF;
END$$;

-- Attempts: users can CRUD only their own rows
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'attempts_select_own') THEN
    CREATE POLICY attempts_select_own ON user_question_attempts
      FOR SELECT USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'attempts_insert_own') THEN
    CREATE POLICY attempts_insert_own ON user_question_attempts
      FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'attempts_update_own') THEN
    CREATE POLICY attempts_update_own ON user_question_attempts
      FOR UPDATE USING (auth.uid() = user_id)
                 WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'attempts_delete_own') THEN
    CREATE POLICY attempts_delete_own ON user_question_attempts
      FOR DELETE USING (auth.uid() = user_id);
  END IF;
END$$;