create or replace function public.update_correct_answer_by_index(
  question_stem text,
  new_correct_answer integer
)
returns void
language plpgsql
as $$
begin
  update public.questions
  set correct_answer = new_correct_answer - 1,  
      updated_at = now()
  where stem = question_stem;

  if not found then
    raise notice 'No question found for stem "%"', question_stem;
  else
    raise notice 'Updated question "%": correct_answer set to % (0-based)', question_stem, new_correct_answer - 1;
  end if;
end;
$$;

select public.update_correct_answer_by_index(
  'A 70-year-old woman with bronchiectasis presents with an exacerbation. Which of the following findings is an appropriate criterion for hospital admission?',
  4
);
