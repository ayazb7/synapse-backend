-- Add a JSONB column that stores selection-aware explanation points.
-- Shape: a JSON object mapping option index ("0".."4") -> array of up to 3 short bullet strings
-- Example:
-- {
--   "2": ["Correct because ...", "…", "…"],
--   "0": ["This option is incorrect because …", "Correct option is … due to …", "Additional reason …"],
--   ...
-- }

alter table if exists public.questions
  add column if not exists explanation_points_by_option jsonb null;

-- Backfill from existing explanation_l1_points where available.
-- For the correct option, reuse existing bullets.
-- For other options, create a generic first bullet about why it's incorrect,
-- followed by up to two bullets from the correct rationale (if available).
update public.questions q
set explanation_points_by_option = jsonb_build_object(
  '0', case when q.correct_answer = 0 then 
          to_jsonb(coalesce(q.explanation_l1_points, array[]::text[]))
        else
          to_jsonb(array[
            'This option is not the best answer for this vignette.',
            coalesce(q.explanation_l1_points[1], 'Key reason: see correct option rationale.'),
            coalesce(q.explanation_l1_points[2], 'Additional reasoning supporting the correct option.')
          ]::text[])
        end,
  '1', case when q.correct_answer = 1 then 
          to_jsonb(coalesce(q.explanation_l1_points, array[]::text[]))
        else
          to_jsonb(array[
            'This option is not the best answer for this vignette.',
            coalesce(q.explanation_l1_points[1], 'Key reason: see correct option rationale.'),
            coalesce(q.explanation_l1_points[2], 'Additional reasoning supporting the correct option.')
          ]::text[])
        end,
  '2', case when q.correct_answer = 2 then 
          to_jsonb(coalesce(q.explanation_l1_points, array[]::text[]))
        else
          to_jsonb(array[
            'This option is not the best answer for this vignette.',
            coalesce(q.explanation_l1_points[1], 'Key reason: see correct option rationale.'),
            coalesce(q.explanation_l1_points[2], 'Additional reasoning supporting the correct option.')
          ]::text[])
        end,
  '3', case when q.correct_answer = 3 then 
          to_jsonb(coalesce(q.explanation_l1_points, array[]::text[]))
        else
          to_jsonb(array[
            'This option is not the best answer for this vignette.',
            coalesce(q.explanation_l1_points[1], 'Key reason: see correct option rationale.'),
            coalesce(q.explanation_l1_points[2], 'Additional reasoning supporting the correct option.')
          ]::text[])
        end,
  '4', case when q.correct_answer = 4 then 
          to_jsonb(coalesce(q.explanation_l1_points, array[]::text[]))
        else
          to_jsonb(array[
            'This option is not the best answer for this vignette.',
            coalesce(q.explanation_l1_points[1], 'Key reason: see correct option rationale.'),
            coalesce(q.explanation_l1_points[2], 'Additional reasoning supporting the correct option.')
          ]::text[])
        end
)
where q.explanation_points_by_option is null;

-- Optional: keep old column for backward compatibility. You can drop later once fully migrated.
-- alter table public.questions drop column explanation_l1_points;


