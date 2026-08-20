"""
MatchIQ - KAN-14 R&D spike
Basic LangChain + DeepSeek feasibility mock-up



Covers:
  Phase 1 - Pre-flight: extract structured task requirements from a JD (LLM)
  Phase 2 - Deterministic screening: score resume tasks against job tasks (no LLM)
  Phase 3 - Rank & cutoff: pick top candidates (no LLM)
  Phase 4 - Judgment: DeepSeek gives structured reasoning on the shortlist (LLM)

Run: python phase_mockup.py
"""

import os
import json
from typing import List
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate

load_dotenv()

llm = ChatOpenAI(
    model="deepseek-chat",  # DeepSeek V3
    api_key=os.environ["DEEPSEEK_API_KEY"],
    base_url="https://api.deepseek.com",
    temperature=0,
)

# ---------------------------------------------------------------------------
# Pydantic schemas = the "structured output" contract for each LLM phase.
# These map directly to the job_profiles / assessment_results columns in the
# System Design Document's Data Design section.
# ---------------------------------------------------------------------------

class JobProfile(BaseModel):
    job_title: str
    task_requirements: List[str] = Field(
        description="Concrete, atomic tasks the job actually requires, "
        "phrased the same way a resume bullet would be phrased."
    )
    trait_language: List[str] = Field(
        description="Any subjective/personality-style phrases in the JD "
        "(e.g. 'digital native', 'culture fit') that aren't concrete tasks."
    )


class CandidateJudgment(BaseModel):
    fit_score: float = Field(description="0-100 holistic fit score")
    matched_tasks: List[str]
    gap_map: List[str] = Field(description="Job tasks this candidate has no evidence for")
    reasoning: str



# Pulled from the real dataset: job_role 'Know Your Customer / Customer Due
# Diligence Analyst' (job_id 0a511d86-...), its 3 work_functions, and all 15
# real key_task rows underneath them (002_seed_data.sql).
SAMPLE_JD = """
Job Title: Know Your Customer / Customer Due Diligence Analyst

The Know Your Customer/Customer Due Diligence Analyst supports the manager
in performing customer onboarding in compliance with regulations, conducts
periodic Know Your Customer (KYC) reviews and checks Customer Due Diligence
(CDD) information of existing accounts. Is the first line of Anti-Money
Laundering (AML) and compliance support and assists in transaction
monitoring, name screening, reporting, and alerting to the relevant parties
where required.

Key responsibilities:
- Communicate with relevant stakeholders to obtain documentation required for customer onboarding
- Conduct risk assessments of new customers
- Request and verify customer information
- Support in conducting due diligence on new customers
- Conduct periodic KYC and CDD checks of existing accounts to ensure adherence to regulatory guidelines
- Provide information to management on any customer issues
- Provide relevant documentation for customer reviews
- Understand due diligence regulations, policies and procedures
- Address queries on KYC issues from internal teams
- Close customer accounts when requested
- File suspicious transaction reports
- Maintain continuous contact with new and existing customers
- Maintain documents and files, updating customer information when required
- Review existing customers including high-risk accounts to ensure customers are within organisation's risk limits
- Understand customers' needs and businesses to monitor activities for unusual transactions
"""

# candidate_1: Mr. Brian Hardin (resume_id 8f9fb427-...), whose resume was
# generated AGAINST this exact job — should score well.
# candidate_2: Benjamin Cooke (resume_id 2e872f49-...), generated against
# 'SysOps Engineer' instead — should score poorly, a genuine mismatch.
CANDIDATES = {
    "candidate_1_brian_hardin_kyc": [
        "Conducted periodic Know Your Customer (KYC) and Customer Due Diligence (CDD) "
        "checks of existing accounts to ensure adherence to regulatory guidelines, and "
        "maintain documents and files, updating customer information when required, "
        "achieving a 15% improvement in audit readiness through close collaboration "
        "with the engineering team.",
        "Reviewed existing customers including high-risk accounts to ensure customers "
        "are within organisation's risk limits.",
        "Supported in conducting due diligence on new customers, contributing to "
        "improved audit readiness.",
    ],
    "candidate_2_benjamin_cooke_sysops": [
        "Oversaw configuration of operational systems to ensure alignment with "
        "technical and security requirements, and perform provisioning of cloud "
        "resources, achieving a 22% improvement in audit readiness through close "
        "collaboration with cross-functional teams.",
        "Translated business needs into cloud architectural requirements.",
        "Built and run large-scale, massively distributed and fault-tolerant "
        "systems, contributing to improved process accuracy.",
    ],
}

# ---------------------------------------------------------------------------
# Phase 1 - extract structured task requirements from raw JD text
# ---------------------------------------------------------------------------

def extract_job_profile(jd_text: str) -> JobProfile:
    prompt = ChatPromptTemplate.from_messages([
        ("system", "Extract structured requirements from this job description. "
                   "Separate concrete tasks from subjective trait language."),
        ("human", "{jd_text}"),
    ])
    structured_llm = llm.with_structured_output(JobProfile)
    chain = prompt | structured_llm
    return chain.invoke({"jd_text": jd_text})


# ---------------------------------------------------------------------------
# Phase 2 - deterministic scoring (NO LLM CALL - pure keyword overlap)
# This is intentionally dumb. The point of the spike is to see how far
# "dumb" gets you before you hit a wall.
# ---------------------------------------------------------------------------

def score_candidate(resume_tasks: List[str], job_tasks: List[str]) -> float:
    job_words = set(" ".join(job_tasks).lower().split())
    resume_words = set(" ".join(resume_tasks).lower().split())
    overlap = job_words & resume_words
    return round(len(overlap) / max(len(job_words), 1) * 100, 1)


# ---------------------------------------------------------------------------
# Phase 4 - LLM judgment on the shortlist only
# ---------------------------------------------------------------------------

def judge_candidate(job_profile: JobProfile, resume_tasks: List[str]) -> CandidateJudgment:
    prompt = ChatPromptTemplate.from_messages([
        ("system", "You are assessing a candidate against a job's task requirements. "
                   "Only use the evidence given, do not assume skills not shown."),
        ("human", "Job tasks required:\n{job_tasks}\n\nCandidate's resume tasks:\n{resume_tasks}"),
    ])
    structured_llm = llm.with_structured_output(CandidateJudgment)
    chain = prompt | structured_llm
    return chain.invoke({
        "job_tasks": "\n".join(job_profile.task_requirements),
        "resume_tasks": "\n".join(resume_tasks),
    })


# ---------------------------------------------------------------------------
# Run the pipeline and print findings
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=== PHASE 1: Extracting job profile from JD ===")
    job_profile = extract_job_profile(SAMPLE_JD)
    print(job_profile.model_dump_json(indent=2))

    print("\n=== PHASE 2: Deterministic scoring ===")
    scores = {}
    for name, tasks in CANDIDATES.items():
        score = score_candidate(tasks, job_profile.task_requirements)
        scores[name] = score
        print(f"{name}: {score}")

    print("\n=== PHASE 3: Rank & cutoff (top 1) ===")
    shortlist = sorted(scores, key=scores.get, reverse=True)[:1]
    print(f"Shortlisted: {shortlist}")

    print("\n=== PHASE 4: Judgment on shortlist ===")
    for name in shortlist:
        judgment = judge_candidate(job_profile, CANDIDATES[name])
        print(f"\n{name}:")
        print(judgment.model_dump_json(indent=2))
