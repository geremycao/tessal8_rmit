# KAN-14 R&D Spike — Findings

Basic LangChain + DeepSeek V3 mock-up covering Phase 1 (JD extraction), Phase 2
(deterministic scoring), Phase 3 (cutoff), Phase 4 (judgment). Built directly
against real rows from the client-provided dataset (read from the .sql files,
not queried from Supabase, since the data load into Supabase isn't done yet).

Per the R&D brief: goal was not "does LangChain beat a raw API call," goal was
finding design gaps by actually running the flow. JD and resume text below are
real rows pulled from `matchiq_selected_insert_data.sql` and
`matchiq_synthetic_resumes.sql` (KYC/CDD Analyst job, candidates Brian Hardin
and Benjamin Cooke), not hand-written.

## Gap 0 — three different descriptions of "the tags," none of which agree

This one has three layers, each caught by checking a different source:

1. **ERD diagram** (and the earlier data-exploration notes, which followed it)
   describe `job_family_tags` on `resume_work_achievement`/`resume_cca_achievement`
   and `sector_tags` on `resume_work_experience`/`resume_cocurricular_activities`.
2. **The actual schema** (`matchiq_selected_create_schema.sql`) doesn't match
   that: only the two achievement tables have a tag column at all, and it's
   just called `tags` — the work_experience/cca parent tables have none.
3. **The verbal explanation given in an earlier sync** was that these tags
   come from Tessal8's edge function, which runs its own matching logic and
   writes back a match score as jsonb. But the actual seeded values in
   `matchiq_synthetic_resumes.sql` are `{"sophistication": "senior",
   "job_role": "SysOps Engineer"}` — a sophistication tier and a free-text job
   role string. No score anywhere in it.

So: ERD says one column name, real schema has a different one, and what was
described as the column's *contents* matches neither. Most likely explanation
is that the synthetic data is a simplified stand-in and the real edge-function
output looks different — but that's an assumption, not confirmed. Worth a
direct, explicit question: what should `tags` actually contain once this is
built for real, and does the column name change too?

## Gap 1 — No enforced link between Resume and Discovery Hub tasks

Confirmed against the real schema: no FK exists from any resume table to
`key_task`/`job`. The only usable link is that free-text `tags.job_role` string,
which happens to match `job_role_name` exactly for this synthetic data — but
that's an artifact of how the generator tagged its own output, not a
constraint the real system can depend on. Phase 2 scoring needs to compare a
candidate's resume tasks against a job's `key_task` rows; there's no clean,
enforced join path to do that. In this mock-up I sidestepped it with plain
keyword overlap on raw achievement text, which is not what the real system can
rely on either.

## Gap 2 — `job_profiles.task_requirements` vs. Discovery Hub's `key_task`

The SDD has Phase 1 extracting task requirements fresh from JD text via DeepSeek
into a new `job_profiles` row. But Discovery Hub already stores each job's task
breakdown in `key_task`. Unclear whether `job_profiles` is meant to duplicate,
validate against, or replace that data. Needs a decision before Phase 1 is built
for real — otherwise we may be extracting something that already exists.

## Gap 3 — Keyword-overlap scoring separates candidates, but the absolute numbers are misleading

Ran the mock-up against real data (KYC job, Brian Hardin vs. Benjamin Cooke).
Results:

| Candidate | Phase 2 keyword-overlap score | Phase 4 fit_score |
|---|---|---|
| Brian Hardin (built for this job) | 42.1 | 45.0 |
| Benjamin Cooke (built for SysOps) | 10.5 | — (not shortlisted) |

The direction is right — the true match clearly outscores the mismatch, so
raw overlap works as a coarse filter. But look at the absolute number: Brian
Hardin's resume was *generated from this exact job's key_tasks* by the
dataset script, and Phase 4 still only found matches for 4 of 14 tasks
(fit_score 45/100), because each resume section only has 3 bullet points by
design (per the handover doc's tiering). That's not a scoring bug — it's
that partial task coverage is the *normal* case for any real resume, not the
exception. If Phase 3's cutoff logic assumes a "good" candidate should cover
most of a job's task list, it will filter out most real candidates,
including genuinely well-matched ones. The cutoff needs to be calibrated
against realistic partial-coverage numbers like this, not against 100%
coverage.

## Gap 2b — Gap 2 isn't hypothetical: it showed up in the actual extraction

Running Phase 1 for real makes Gap 2 concrete rather than theoretical.
Comparing DeepSeek's `task_requirements` output against the real `key_task`
rows for this job:

- The real key_task **"Understand due diligence regulations, policies and
  procedures"** was extracted straight into `trait_language`, not
  `task_requirements` — it's dropped from the task list entirely.
- The real key_task **"Understand customers' needs and businesses to monitor
  activities for unusual transactions"** got split: half was rephrased into
  a `task_requirements` entry ("Monitor customer activities for unusual
  transactions based on understanding of customers' needs and businesses"),
  half ("Understand customers' needs and businesses") was separately filed
  under `trait_language`.

So on the exact same source text, fresh LLM extraction already disagrees
with the existing `key_task` ground truth — one real task lost, one altered
and duplicated. If `job_profiles.task_requirements` becomes the thing Phase 2
actually scores against (rather than `key_task`), this is a live risk, not
a hypothetical one: real requirements can silently drop out of scoring
depending on how the JD happens to be phrased, with no error or flag raised
anywhere.

## Gap 5 — RLS enabled but no policies on resume/user tables yet

`003_rls_policies.sql` (KAN-10) enables RLS on `app_user`,
`resume`, and every resume child table, but intentionally adds no policies —
deferred pending confirmation of how `app_user.user_id` maps to Supabase
Auth's `auth.users.id`. Reference/Discovery Hub tables get open `select`
policies for any authenticated user, which is fine. But RLS-enabled with no
policy means deny-all by default: any script or Edge Function hitting the
resume tables with a normal key gets zero rows until either a policy is added
or the query uses the service_role key. This will block re-running the
mock-up against real Supabase data (the next step below) unless flagged now.

## Gap 6 — no employer/tenant concept exists in the schema

The SDD's security section (8.4) scopes every employer-facing table by
`employer_id` via RLS, and `batch_runs`/`job_profiles` are described as
belonging to one employer's match run. But `job` (and everything above it —
`sector`, `track`, `job_role`) has no `employer_id` column, and there's no
`employer` table anywhere in the ERD. The current `job` table is a generic,
shared taxonomy entry (e.g. "SysOps Engineer" as a role that exists across the
whole dataset), not a specific employer's posting of that role. The SDD's
employer-scoping model has nothing to attach to as designed — either a new
employer entity needs introducing, or the relationship between "generic job
role" and "one employer's posting of it" needs defining before `job_profiles`/
`batch_runs` can actually be built with the RLS the SDD promises.

Output from phase_mockups.py
<img width="975" height="864" alt="image (1)" src="https://github.com/user-attachments/assets/a7e2c791-2241-45b6-8b91-ccddcdf44f29" />
<img width="1372" height="384" alt="image" src="https://github.com/user-attachments/assets/ba0721f1-abb2-4da7-b414-77aa6adc1ccb" />

## Next steps

- Raise Gap 0 directly and separately with whoever owns the ERD/tags
  decision — it's a naming/content question that needs answering before
  the ERD's resume tables get extended further.
- Raise Gap 6 as early as possible — it's an architecture decision (does an
  employer entity need to be added to the ERD?) that the rest of the
  processing-table design (job_profiles, batch_runs) depends on.
- Raise Gap 2 / Gap 2b together — this is no longer a theoretical concern,
  it happened on the first real extraction run. Needs a decision on whether
  Phase 1 extracts fresh or validates against `key_task` before Phase 1 gets
  built for real.
- Raise Gap 3's cutoff-calibration point with whoever owns Phase 3's ranking
  logic — a 100%-coverage assumption will filter out real candidates.
- Raise Gap 1 and Gap 5 with the team before ERD/RLS work goes further —
  cheaper to resolve now than after tables and policies are built on the
  current assumptions.
- This mock-up used one job and two candidates by hand-picking clear
  match/mismatch cases. Re-run against a larger random sample once the
  team's Supabase load is done and Gap 5's RLS policy question is
  resolved, to confirm Gap 3's coverage pattern holds at scale rather than
  just on these two.
