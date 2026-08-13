-- ============================================================
-- MatchIQ - Synthetic Dataset Subset - CREATE SCHEMA
--
-- Contains only the tables selected from the MatchIQ ERD v0.1
-- (Fixed Values, app_user/user_has_skill, Discovery Hub, and
-- Resume table groups). Extracted verbatim from create_schema.sql,
-- reordered so foreign-key dependencies are created before the
-- tables that reference them.
-- ============================================================

create extension if not exists "pgcrypto";

-- ============================================================
-- FIXED VALUES TABLES
-- ============================================================

create table sector (
  sector_id           uuid primary key,
  sector_name         text not null,
  sector_description  text,
  created_at          timestamp default now(),
  created_by          text,
  updated_at          timestamp default now(),
  updated_by          text,
  constraint sector_name_key unique (sector_name)
);

create table track (
  track_id    uuid primary key,
  track_name  text not null,
  created_at  timestamp default now(),
  created_by  text,
  updated_at  timestamp default now(),
  updated_by  text,
  constraint track_name_key unique (track_name)
);

create table job_role (
  job_role_id           uuid primary key,
  job_role_name         text not null,
  job_role_description  text,
  created_at            timestamp default now(),
  created_by            text,
  updated_at            timestamp default now(),
  updated_by            text,
  constraint job_role_name_key unique (job_role_name)
);

create table job (
  job_id      uuid primary key,
  sector_id   uuid references sector(sector_id),
  track_id    uuid references track(track_id),
  job_role_id uuid references job_role(job_role_id),
  created_at  timestamp default now(),
  created_by  text,
  updated_at  timestamp default now(),
  updated_by  text,
  constraint job_sector_track_role_key unique (sector_id, track_id, job_role_id)
);

create table skill (
  skill_id    uuid primary key,
  skill_name  text not null,
  created_at  timestamp default now(),
  created_by  text,
  updated_at  timestamp default now(),
  updated_by  text
);

create table skill_proficiency (
  skill_proficiency_id  uuid primary key,
  skill_id              uuid references skill(skill_id),
  job_role_id           uuid references job_role(job_role_id),
  proficiency_level     numeric,
  created_at            timestamp default now(),
  created_by            text,
  updated_at            timestamp default now(),
  updated_by            text
);

create table job_requires_skill (
  job_id                uuid references job(job_id),
  skill_proficiency_id  uuid references skill_proficiency(skill_proficiency_id),
  created_at            timestamp default now(),
  created_by            text,
  updated_at            timestamp default now(),
  updated_by            text,
  primary key (job_id, skill_proficiency_id)
);

create table if not exists skill_weights (
  scenario_no  integer not null check (scenario_no in (1, 2, 3)),
  skill_id     uuid references skill(skill_id) on delete cascade,
  weight       numeric not null check (weight >= 0 and weight <= 1),
  primary key (scenario_no, skill_id)
);

create table template_types (
  template_id   uuid primary key default gen_random_uuid(),
  template_name text not null,
  description   text,
  created_at    timestamp default now(),
  created_by    text,
  updated_at    timestamp default now(),
  updated_by    text
);

-- ============================================================
-- USER TABLE
-- ============================================================

create table app_user (
  user_id       uuid primary key default gen_random_uuid(),
  name          text,
  is_authorized boolean default false,
  user_permission text,
  email_address text unique,
  user_phone    text,
  nationality   text,
  created_at    timestamp default now(),
  created_by    text,
  updated_at    timestamp default now(),
  updated_by    text
);

create table user_has_skill (
  user_id               uuid references app_user(user_id) on delete cascade,
  skill_proficiency_id  uuid references skill_proficiency(skill_proficiency_id),
  created_at            timestamp default now(),
  created_by            text,
  updated_at            timestamp default now(),
  updated_by            text,
  primary key (user_id, skill_proficiency_id)
);

-- ============================================================
-- DISCOVERY HUB TABLES
-- ============================================================

create table job_family (
  job_family_id   uuid primary key default gen_random_uuid(),
  job_family_name text not null,
  created_at      timestamp default now(),
  created_by      text,
  updated_at      timestamp default now(),
  updated_by      text,
  constraint job_family_name_key unique (job_family_name)
);

create table work_type (
  work_type_id   uuid primary key default gen_random_uuid(),
  work_type_name text not null,
  created_at     timestamp default now(),
  created_by     text,
  updated_at     timestamp default now(),
  updated_by     text,
  constraint work_type_name_key unique (work_type_name)
);

create table work_function (
  work_function_id   uuid primary key default gen_random_uuid(),
  job_id             uuid not null references job(job_id),
  job_family_id      uuid references job_family(job_family_id),
  work_function_name text not null,
  display_order      integer,
  created_at         timestamp default now(),
  created_by         text,
  updated_at         timestamp default now(),
  updated_by         text,
  constraint work_function_job_name_key unique (job_id, work_function_name)
);

create table key_task (
  key_task_id      uuid primary key default gen_random_uuid(),
  work_function_id uuid not null references work_function(work_function_id) on delete cascade,
  work_type_id     uuid references work_type(work_type_id),
  task_text        text not null,
  display_order    integer,
  created_at       timestamp default now(),
  created_by       text,
  updated_at       timestamp default now(),
  updated_by       text,
  constraint key_task_wf_text_key unique (work_function_id, task_text)
);

-- ============================================================
-- RESUME TABLES
-- ============================================================

create table resume (
  resume_id     uuid primary key default gen_random_uuid(),
  user_id       uuid references app_user(user_id) on delete cascade,
  template_id   uuid references template_types(template_id),
  resume_title  text,
  is_completed  boolean default false,
  created_at    timestamp default now(),
  created_by    text,
  updated_at    timestamp default now(),
  updated_by    text
);

create table resume_personal_info (
  pers_info_id    uuid primary key default gen_random_uuid(),
  resume_id       uuid references resume(resume_id) on delete cascade,
  full_name       text,
  email           text,
  job_name        text,
  phone_extension text,
  contact_number  text,
  linkedin_url    text,
  country         text,
  city_state      text,
  address         text,
  created_at      timestamp default now(),
  created_by      text,
  updated_at      timestamp default now(),
  updated_by      text
);

create table resume_education (
  edu_id        uuid primary key default gen_random_uuid(),
  resume_id     uuid references resume(resume_id) on delete cascade,
  institution   text,
  degree        text,
  start_date    timestamp,
  end_date      timestamp,
  description   text,
  is_current    boolean default false,
  is_selected   boolean default true,
  display_order integer,
  created_at    timestamp default now(),
  created_by    text,
  updated_at    timestamp default now(),
  updated_by    text
);

create table resume_work_experience (
  work_exp_id   uuid primary key default gen_random_uuid(),
  resume_id     uuid references resume(resume_id) on delete cascade,
  display_order integer,
  organization  text,
  position      text,
  start_date    timestamp,
  end_date      timestamp,
  is_current    boolean default false,
  is_selected   boolean default true,
  created_at    timestamp default now(),
  created_by    text,
  updated_at    timestamp default now(),
  updated_by    text
);

create table resume_work_achievement (
  achievement_id uuid primary key default gen_random_uuid(),
  work_exp_id    uuid not null references resume_work_experience(work_exp_id) on delete cascade,
  achievement_text text not null,
  tags           jsonb,
  created_at     timestamp default now(),
  created_by     text,
  updated_at     timestamp default now(),
  updated_by     text
);

create table resume_cocurricular_activities (
  cca_id        uuid primary key default gen_random_uuid(),
  resume_id     uuid references resume(resume_id) on delete cascade,
  club_name     text,
  position      text,
  start_date    timestamp,
  end_date      timestamp,
  is_current    boolean default false,
  is_selected   boolean default true,
  display_order integer,
  created_at    timestamp default now(),
  created_by    text,
  updated_at    timestamp default now(),
  updated_by    text
);

create table resume_cca_achievement (
  achievement_id uuid primary key default gen_random_uuid(),
  cca_id         uuid not null references resume_cocurricular_activities(cca_id) on delete cascade,
  achievement_text text not null,
  tags           jsonb,
  created_at     timestamp default now(),
  created_by     text,
  updated_at     timestamp default now(),
  updated_by     text
);

create table resume_additional (
  additional_id    uuid primary key default gen_random_uuid(),
  resume_id        uuid references resume(resume_id) on delete cascade,
  is_selected      boolean default true,
  languages        text[],
  technical_skills text[],
  soft_skills      text[],
  interests        text[],
  created_at       timestamp default now(),
  created_by       text,
  updated_at       timestamp default now(),
  updated_by       text
);
