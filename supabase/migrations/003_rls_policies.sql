-- ============================================================
-- KAN-10: Row Level Security Policies
-- ============================================================
-- Reference/ontology tables are readable by authenticated users.
-- Writes remain unavailable to normal authenticated users.
--
-- User-owned table policies are intentionally deferred until the
-- relationship between app_user.user_id and Supabase auth.users.id
-- is confirmed.
-- ============================================================


-- ============================================================
-- FIXED VALUES / REFERENCE TABLES
-- ============================================================

alter table sector enable row level security;
alter table track enable row level security;
alter table job_role enable row level security;
alter table job enable row level security;
alter table skill enable row level security;
alter table skill_proficiency enable row level security;
alter table job_requires_skill enable row level security;
alter table skill_weights enable row level security;
alter table template_types enable row level security;


create policy "Authenticated users can read sectors"
on sector
for select
to authenticated
using (true);

create policy "Authenticated users can read tracks"
on track
for select
to authenticated
using (true);

create policy "Authenticated users can read job roles"
on job_role
for select
to authenticated
using (true);

create policy "Authenticated users can read jobs"
on job
for select
to authenticated
using (true);

create policy "Authenticated users can read skills"
on skill
for select
to authenticated
using (true);

create policy "Authenticated users can read skill proficiency"
on skill_proficiency
for select
to authenticated
using (true);

create policy "Authenticated users can read job required skills"
on job_requires_skill
for select
to authenticated
using (true);

create policy "Authenticated users can read skill weights"
on skill_weights
for select
to authenticated
using (true);

create policy "Authenticated users can read template types"
on template_types
for select
to authenticated
using (true);


-- ============================================================
-- DISCOVERY HUB
-- ============================================================

alter table job_family enable row level security;
alter table work_type enable row level security;
alter table work_function enable row level security;
alter table key_task enable row level security;


create policy "Authenticated users can read job families"
on job_family
for select
to authenticated
using (true);

create policy "Authenticated users can read work types"
on work_type
for select
to authenticated
using (true);

create policy "Authenticated users can read work functions"
on work_function
for select
to authenticated
using (true);

create policy "Authenticated users can read key tasks"
on key_task
for select
to authenticated
using (true);


-- ============================================================
-- USER-OWNED TABLES
-- ============================================================
-- RLS is enabled here so these tables are protected by default.
-- Access policies will be added once the app_user <-> Supabase
-- Auth identity relationship is confirmed.
-- ============================================================

alter table app_user enable row level security;
alter table user_has_skill enable row level security;

alter table resume enable row level security;
alter table resume_personal_info enable row level security;
alter table resume_education enable row level security;
alter table resume_work_experience enable row level security;
alter table resume_work_achievement enable row level security;
alter table resume_cocurricular_activities enable row level security;
alter table resume_cca_achievement enable row level security;
alter table resume_additional enable row level security;