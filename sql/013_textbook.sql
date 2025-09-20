-- Textbook content schema: pages, sections, blocks, citations, tags
-- Links to existing specialties/topics taxonomy

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums (create if missing)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'content_status') THEN
    CREATE TYPE content_status AS ENUM ('draft','published','archived');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'textbook_section_type') THEN
    CREATE TYPE textbook_section_type AS ENUM (
      'overview',
      'pathophysiology',
      'epidemiology_risk_factors',
      'clinical_features',
      'investigations',
      'management',
      'complications',
      'prognosis',
      'references',
      'custom'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'textbook_block_type') THEN
    CREATE TYPE textbook_block_type AS ENUM (
      'markdown',     -- Generic Markdown content (paragraphs, lists, headings)
      'image',        -- Image with metadata stored in data JSON
      'quote',        -- Quotation/callout
      'table',        -- Table represented in Markdown or data JSON
      'code',         -- Code snippets
      'math'          -- TeX/MathJax blocks
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'citation_type') THEN
    CREATE TYPE citation_type AS ENUM ('guideline','journal','book','website','database','other');
  END IF;
END$$;

-- 1) Textbook pages (one canonical page per topic)
CREATE TABLE IF NOT EXISTS textbook_pages (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id     uuid NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  title        text NOT NULL,
  slug         text NOT NULL, -- page slug for URLs (e.g., "acid-base-abnormality")
  summary      text,          -- short abstract for cards/SEO
  status       content_status NOT NULL DEFAULT 'draft',
  version      integer NOT NULL DEFAULT 1,
  created_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (topic_id),
  UNIQUE (slug)
);

-- updated_at trigger for textbook_pages
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_textbook_pages_updated_at') THEN
    CREATE TRIGGER trg_textbook_pages_updated_at
    BEFORE UPDATE ON textbook_pages
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS textbook_pages_topic_idx ON textbook_pages(topic_id);
CREATE INDEX IF NOT EXISTS textbook_pages_status_idx ON textbook_pages(status);

-- 2) Hierarchical sections (supports sub-sections via parent_section_id)
CREATE TABLE IF NOT EXISTS textbook_sections (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id              uuid NOT NULL REFERENCES textbook_pages(id) ON DELETE CASCADE,
  parent_section_id    uuid REFERENCES textbook_sections(id) ON DELETE CASCADE,
  title                text NOT NULL,
  anchor_slug          text NOT NULL, -- for in-page anchors (e.g., "epidemiology-risk-factors")
  section_type         textbook_section_type NOT NULL DEFAULT 'custom',
  position             integer NOT NULL DEFAULT 1, -- order within parent
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (page_id, anchor_slug),
  UNIQUE (page_id, parent_section_id, position)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_textbook_sections_updated_at') THEN
    CREATE TRIGGER trg_textbook_sections_updated_at
    BEFORE UPDATE ON textbook_sections
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS textbook_sections_page_idx ON textbook_sections(page_id);
CREATE INDEX IF NOT EXISTS textbook_sections_parent_idx ON textbook_sections(parent_section_id);

-- 3) Section content blocks (flexible content model)
-- For block_type='markdown', put Markdown in content and leave data as '{}'.
-- For block_type='image', set data JSON with keys: url, alt, caption, attribution, license, source_url, width, height.
CREATE TABLE IF NOT EXISTS textbook_blocks (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id   uuid NOT NULL REFERENCES textbook_sections(id) ON DELETE CASCADE,
  block_type   textbook_block_type NOT NULL DEFAULT 'markdown',
  content      text,        -- Markdown or plain text
  data         jsonb NOT NULL DEFAULT '{}',
  position     integer NOT NULL DEFAULT 1, -- order within section
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CHECK ((block_type <> 'markdown') OR (content IS NOT NULL))
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_textbook_blocks_updated_at') THEN
    CREATE TRIGGER trg_textbook_blocks_updated_at
    BEFORE UPDATE ON textbook_blocks
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS textbook_blocks_section_idx ON textbook_blocks(section_id);
CREATE INDEX IF NOT EXISTS textbook_blocks_type_idx ON textbook_blocks(block_type);

-- 4) Citations / references (per page, optionally linked to a section)
CREATE TABLE IF NOT EXISTS textbook_citations (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id       uuid NOT NULL REFERENCES textbook_pages(id) ON DELETE CASCADE,
  section_id    uuid REFERENCES textbook_sections(id) ON DELETE SET NULL,
  citation_key  text,              -- e.g. short key like "NICE-NG51"
  label         text,              -- human-readable label to render
  source_type   citation_type NOT NULL DEFAULT 'other',
  authors       text,              -- free-text author list
  year          integer,
  publisher     text,
  url           text,
  accessed_on   date,
  raw_citation  text,              -- if you have a preformatted reference
  position      integer NOT NULL DEFAULT 1,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_textbook_citations_updated_at') THEN
    CREATE TRIGGER trg_textbook_citations_updated_at
    BEFORE UPDATE ON textbook_citations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS textbook_citations_page_idx ON textbook_citations(page_id);
CREATE INDEX IF NOT EXISTS textbook_citations_section_idx ON textbook_citations(section_id);

-- 5) Simple tag support for pages (useful for search/filters)
CREATE TABLE IF NOT EXISTS textbook_page_tags (
  page_id   uuid NOT NULL REFERENCES textbook_pages(id) ON DELETE CASCADE,
  tag       text NOT NULL,
  PRIMARY KEY (page_id, tag)
);

-- 6) Convenience views
-- Outline for navigation: specialty -> topic -> page -> sections (top-level only)
CREATE OR REPLACE VIEW v_textbook_outline AS
SELECT
  s.id            AS specialty_id,
  s.name          AS specialty_name,
  s.slug          AS specialty_slug,
  t.id            AS topic_id,
  t.name          AS topic_name,
  t.slug          AS topic_slug,
  p.id            AS page_id,
  p.title         AS page_title,
  p.slug          AS page_slug,
  p.status        AS page_status,
  sec.id          AS section_id,
  sec.title       AS section_title,
  sec.anchor_slug AS section_anchor,
  sec.section_type,
  sec.position    AS section_position
FROM specialties s
JOIN topics t ON t.specialty_id = s.id
LEFT JOIN textbook_pages p ON p.topic_id = t.id
LEFT JOIN textbook_sections sec ON sec.page_id = p.id AND sec.parent_section_id IS NULL
ORDER BY s.name, t.name, sec.position;

-- Flattened blocks for a page (useful for rendering in order)
CREATE OR REPLACE VIEW v_textbook_blocks AS
SELECT
  p.id          AS page_id,
  sec.id        AS section_id,
  sec.parent_section_id,
  sec.title     AS section_title,
  sec.anchor_slug,
  sec.section_type,
  sec.position  AS section_position,
  b.id          AS block_id,
  b.block_type,
  b.position    AS block_position,
  b.content,
  b.data
FROM textbook_pages p
JOIN textbook_sections sec ON sec.page_id = p.id
JOIN textbook_blocks b ON b.section_id = sec.id
ORDER BY section_position, block_position;

-- 7) Row-Level Security (public read-only)
ALTER TABLE textbook_pages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE textbook_sections   ENABLE ROW LEVEL SECURITY;
ALTER TABLE textbook_blocks     ENABLE ROW LEVEL SECURITY;
ALTER TABLE textbook_citations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE textbook_page_tags  ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'textbook_pages_read_all') THEN
    CREATE POLICY textbook_pages_read_all ON textbook_pages FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'textbook_sections_read_all') THEN
    CREATE POLICY textbook_sections_read_all ON textbook_sections FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'textbook_blocks_read_all') THEN
    CREATE POLICY textbook_blocks_read_all ON textbook_blocks FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'textbook_citations_read_all') THEN
    CREATE POLICY textbook_citations_read_all ON textbook_citations FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'textbook_page_tags_read_all') THEN
    CREATE POLICY textbook_page_tags_read_all ON textbook_page_tags FOR SELECT USING (true);
  END IF;
END$$;


