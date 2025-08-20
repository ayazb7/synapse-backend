# generate_heart_failure_sbas.py
# Purpose: Generate 200 UKMLA-style SBA questions for Heart Failure (Cardiology) in JSONL format.
# Output: out/heart_failure.jsonl (one SBA object per line, schema per your PDF)

import os
import json
import time
import random
from dataclasses import dataclass, asdict
from typing import List, Dict, Any, Tuple

from dotenv import load_dotenv
from tqdm import tqdm

# --- Optional similarity (will fall back if sklearn not available) ---
try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity
    HAVE_SKLEARN = True
except Exception:
    HAVE_SKLEARN = False

# --- OpenAI v1 client ---
try:
    from openai import OpenAI
    client = OpenAI()
except Exception as e:
    raise RuntimeError("OpenAI client not available. Install openai>=1.0 and set OPENAI_API_KEY.") from e

# ----------------- CONFIG -----------------
CONDITION = "Heart Failure"              # <- as requested
AREA_OF_PRACTICE = "Cardiology"         # <- as requested
MODEL = "gpt-4o"                        # choose a current model you have access to
SEEDS_PER_CONDITION = 10               
VARIANTS_PER_SEED = 2
TARGET_SBAS = 20
OUTDIR = "out"
OUTFILE = os.path.join(OUTDIR, "heart_failure.jsonl")

# Safety / quality
SIM_THRESHOLD = 0.75                    # near-duplicate threshold if sklearn available
CHECKPOINT_EVERY = 20                   # write to disk every N accepted items
DELAY_BETWEEN_CALLS = 0.4               # seconds; gentle pacing

# Token-ish limits for JSON outputs
MAX_TOKENS_SEEDS = 2000
MAX_TOKENS_SBA   = 2200

# ----------------- DATA SCHEMA -----------------
@dataclass
class SBA:
    # Matches Section 7 of your PDF
    question_id: str
    condition: str
    area_of_practice: str
    vignette: str
    options: Dict[str, str]                   # keys A–E
    correct_option: str                       # "A"..."E"
    level1_rationale: str
    level2_context: str
    level3_eli5: str
    media_type: str
    media_annotation: str
    exam_tip: str
    mnemonic: str
    difficulty: str
    time_sec: int
    cognitive_skill: str
    tags: List[str]
    mla_outcomes: List[str]
    guideline_refs: List[str]
    textbook_anchor: str
    qr_guideline_link: str

# ----------------- PROMPTS -----------------
SYSTEM_EDU = (
    "You are an expert UK medical educator creating UKMLA-style Single Best Answer (SBA) questions "
    "for the SynapseUK platform. Follow NICE/BNF/Resus Council UK guidance. Exactly one best answer per SBA."
)

SEED_PLANNER_USER = (
    "Create {n} distinct seed clinical scenarios for the condition \"{condition}\", "
    "mapped to \"{areas}\" in the MLA content map.\n"
    "Cover a balanced grid across: focus (Diagnosis/Investigations/Interpretation/AcuteMx/ChronicMx/Complications/Prevention/Monitoring/Safety-net), "
    "setting (GP/ED/AMU/ward/theatre/recovery/community), patient factors (child/adult/older adult/pregnancy/frailty/multimorbidity/common meds), "
    "red flags (sepsis/ACS/anaphylaxis/safeguarding/DNACPR-capacity), planned media (ECG/CXR/ABG/echo/bloods/urinalysis/bedside tests), "
    "difficulty split (40% Easy, 45% Moderate, 15% Hard), and cognitive skill (recognition/data interpretation/prioritisation/prescribing/ethics-law).\n"
    "Return ONLY a JSON object with key \"seeds\" whose value is an array. No prose, no markdown.\n"
    "Each seed item MUST have these string fields: seed_id, vignette_stub, focus, setting, patient_factors, red_flags, planned_media, difficulty, cognitive_skill, guideline_hook."
)

VARIANT_GENERATOR_USER = (
    "Input seed: {seed_json}\n\n"
    "Generate {k} unique UKMLA Single Best Answer questions (A–E options).\n"
    "Rules:\n"
    "- Final-year UK MLAAKT; align with NICE/BNF/Resus Council UK.\n"
    "- Change ≥2 scenario dimensions from the seed for each SBA.\n"
    "- Provide multi-level explanations (level1 rationale incl. wrong options, level2 context + named guideline, level3 ELI5 analogy/mnemonic).\n"
    "- Include media suggestion, one exam tip, one mnemonic.\n"
    "- Include metadata: area_of_practice, mla_outcomes, difficulty, time_sec, cognitive_skill, tags, guideline_refs, textbook_anchor, qr_guideline_link.\n\n"
    "Return ONLY a JSON object with key \"sbas\" whose value is an array. No prose, no markdown.\n"
    "Each SBA item MUST have fields: vignette (string), options (object with keys A,B,C,D,E), correct (one of A–E), "
    "level1, level2, level3 (strings), media_type, media_annotation, exam_tip, mnemonic (strings), "
    "area_of_practice (string), mla_outcomes (array of strings), difficulty (Easy/Moderate/Hard), time_sec (int), "
    "cognitive_skill (string), tags (array of strings), guideline_refs (array of strings), textbook_anchor (string), qr_guideline_link (string)."
)

# ----------------- HELPERS -----------------
def ensure_outdir(path: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)

def repair_json(raw_content: str, top_key: str, model: str) -> Any:
    """
    Ask the model to repair a partial/bad JSON string into a strict JSON object
    with a specific top-level key (e.g., 'seeds' or 'sbas').
    """
    prompt = (
        f"You will be given a possibly truncated or invalid JSON blob.\n"
        f"Return ONLY a valid strict JSON object whose top-level key is \"{top_key}\".\n"
        f"Do not add commentary or markdown. If the array is incomplete, complete it sensibly.\n\n"
        f"INPUT START\n{raw_content}\nINPUT END"
    )
    resp = client.chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": "You fix JSON strictly."},
                  {"role": "user", "content": prompt}],
        temperature=0.0,
        response_format={"type": "json_object"},
        max_tokens=2000,
    )
    fixed = resp.choices[0].message.content or ""
    try:
        return json.loads(fixed)
    except Exception:
        import json5
        return json5.loads(fixed)

def chat_json(system: str, user: str, model: str, max_tokens: int, top_key: str) -> Any:
    """Call OpenAI with JSON response formatting and parse JSON robustly; repair if needed."""
    resp = client.chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
        temperature=0.7,
        response_format={"type": "json_object"},
        max_tokens=max_tokens,
    )
    content = resp.choices[0].message.content or ""

    # Strip any markdown fences if present
    if "```" in content:
        # keep the largest fenced block or just remove backticks
        parts = content.split("```")
        # heuristic: pick the longest part that looks like JSON
        candidates = sorted(parts, key=len, reverse=True)
        for c in candidates:
            if "{" in c and "}" in c:
                content = c
                break

    # Try strict JSON
    try:
        return json.loads(content)
    except Exception:
        pass

    # Try JSON5 if available
    try:
        import json5  # pip install json5
        return json5.loads(content)
    except Exception:
        # last resort: ask the model to repair to {top_key: [...]}
        return repair_json(content, top_key=top_key, model=model)


def vectorizer_fit(corpus: List[str]):
    if not HAVE_SKLEARN:
        return None, None
    vec = TfidfVectorizer(min_df=1, ngram_range=(1,2))
    X = vec.fit_transform(corpus)
    return vec, X

def similarity_score(vec, X, text: str) -> float:
    if not HAVE_SKLEARN or vec is None or X is None or X.shape[0] == 0:
        return 0.0
    q = vec.transform([text])
    sims = cosine_similarity(q, X)[0]
    return float(sims.max()) if sims.size else 0.0

def sba_signature_fields(vignette: str, options: Dict[str,str]) -> str:
    # Concise signature for dedup
    opts = " ".join([options.get(k, "") for k in ["A","B","C","D","E"]])
    return (vignette.strip() + " " + opts.strip())[:5000]

def normalize_options(options_obj: Any) -> Dict[str, str]:
    # Accepts {"A": "...", "B": "..."} or {"options(A–E)": {...}}
    if isinstance(options_obj, dict) and all(k.upper()[:1] in {"A","B","C","D","E"} for k in options_obj.keys()):
        norm = {k.strip().upper()[:1]: str(v) for k, v in options_obj.items()}
        return {k: norm.get(k, "") for k in ["A","B","C","D","E"]}
    # Fallback if nested or different key
    try:
        inner = options_obj.get("options(A–E)") if isinstance(options_obj, dict) else {}
        norm = {k.strip().upper()[:1]: str(v) for k, v in inner.items()}
        return {k: norm.get(k, "") for k in ["A","B","C","D","E"]}
    except Exception:
        return {k: "" for k in ["A","B","C","D","E"]}

def to_sba_objects(condition: str, area: str, seed_id: str, items: List[Dict[str, Any]]) -> List[SBA]:
    sbas: List[SBA] = []
    for i, it in enumerate(items, 1):
        options_dict = it.get("options") or it.get("options(A–E)") or {}
        options = normalize_options(options_dict if isinstance(options_dict, dict) else {"options(A–E)": options_dict})
        correct = (it.get("correct") or it.get("correct_option") or "").strip()[:1].upper()
        
        cond_clean = condition.lower().replace(" ", "_").replace("\u00A0", "_")
        qid = f"{cond_clean}-{seed_id}-{i:02d}"

        sba = SBA(
            question_id=qid,
            condition=condition,
            area_of_practice=it.get("area_of_practice", area),
            vignette=it.get("vignette", "").strip(),
            options=options,
            correct_option=correct,
            level1_rationale=it.get("level1", it.get("level1_rationale","")).strip(),
            level2_context=it.get("level2", it.get("level2_context","")).strip(),
            level3_eli5=it.get("level3", it.get("level3_eli5","")).strip(),
            media_type=it.get("media_type","").strip(),
            media_annotation=it.get("media_annotation","").strip(),
            exam_tip=it.get("exam_tip","").strip(),
            mnemonic=it.get("mnemonic","").strip(),
            difficulty=it.get("difficulty","Moderate").strip() or "Moderate",
            time_sec=int(it.get("time_sec", 90) or 90),
            cognitive_skill=it.get("cognitive_skill","recognition").strip() or "recognition",
            tags=list(it.get("tags", [])),
            mla_outcomes=list(it.get("mla_outcomes", [])),
            guideline_refs=list(it.get("guideline_refs", [])),
            textbook_anchor=it.get("textbook_anchor","").strip(),
            qr_guideline_link=it.get("qr_guideline_link","").strip(),
        )
        sbas.append(sba)
    return sbas


def quality_gate(new_sba: SBA, accepted: List[SBA], vec=None, X=None) -> Tuple[bool, Any, Any]:
    # one-best-answer sanity
    if new_sba.correct_option not in {"A","B","C","D","E"}:
        return False, vec, X
    # minimal completeness
    if not new_sba.vignette or any(not v for v in new_sba.options.values()):
        return False, vec, X
    # similarity dedup (if sklearn)
    if HAVE_SKLEARN and accepted:
        corpus = [sba_signature_fields(s.vignette, s.options) for s in accepted]
        vec, X = vectorizer_fit(corpus)
        sim = similarity_score(vec, X, sba_signature_fields(new_sba.vignette, new_sba.options))
        if sim >= SIM_THRESHOLD:
            return False, vec, X
    else:
        # simple hash dedup fallback
        sigs = {sba_signature_fields(s.vignette, s.options) for s in accepted}
        if sba_signature_fields(new_sba.vignette, new_sba.options) in sigs:
            return False, vec, X
    return True, vec, X

def save_jsonl(path: str, sbas: List[SBA]):
    ensure_outdir(path)
    with open(path, "w", encoding="utf-8") as f:
        for s in sbas:
            f.write(json.dumps(asdict(s), ensure_ascii=False) + "\n")

def append_jsonl(path: str, sbas: List[SBA]):
    ensure_outdir(path)
    with open(path, "a", encoding="utf-8") as f:
        for s in sbas:
            f.write(json.dumps(asdict(s), ensure_ascii=False) + "\n")

def load_existing(path: str) -> List[SBA]:
    existing: List[SBA] = []
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                existing.append(SBA(**json.loads(line)))
    return existing

# ----------------- PIPELINE -----------------
def generate_seeds(condition: str, areas: str, model: str) -> List[Dict[str, Any]]:
    data = chat_json(SYSTEM_EDU, SEED_PLANNER_USER.format(n=SEEDS_PER_CONDITION, condition=condition, areas=areas), model, MAX_TOKENS_SEEDS)
    if isinstance(data, dict) and isinstance(data.get("seeds"), list):
        return data["seeds"]
    raise ValueError("Seed planner returned unexpected format")

def expand_seed_to_sbas(condition: str, areas: str, seed: Dict[str, Any], model: str) -> List[SBA]:
    seed_id = str(seed.get("seed_id", f"seed-{random.randint(1000,9999)}"))
    data = chat_json(SYSTEM_EDU, VARIANT_GENERATOR_USER.format(seed_json=json.dumps(seed, ensure_ascii=False), k=VARIANTS_PER_SEED), model, MAX_TOKENS_SBA)
    items = data.get("sbas", []) if isinstance(data, dict) else []
    return to_sba_objects(condition, areas, seed_id, items)

def main():
    # Resume-safe
    accepted: List[SBA] = load_existing(OUTFILE)
    if accepted:
        print(f"Resuming: found {len(accepted)} existing SBAs in {OUTFILE}")

    if len(accepted) >= TARGET_SBAS:
        print(f"Target already met: {len(accepted)} SBAs")
        return

    print(f"Generating seeds for {CONDITION} / {AREA_OF_PRACTICE} ...")
    seeds = generate_seeds(CONDITION, AREA_OF_PRACTICE, MODEL)
    random.shuffle(seeds)

    # Progress bar reflects remaining to reach target
    pbar = tqdm(total=TARGET_SBAS, desc=f"{CONDITION}")
    pbar.update(len(accepted))

    # For dedup
    vec = None
    X = None

    for seed in seeds:
        if len(accepted) >= TARGET_SBAS:
            break
        try:
            batch = expand_seed_to_sbas(CONDITION, AREA_OF_PRACTICE, seed, MODEL)
        except Exception as e:
            print("Seed expansion failed:", e)
            continue

        # QC
        to_append: List[SBA] = []
        for sba in batch:
            if len(accepted) >= TARGET_SBAS:
                break
            ok, vec, X = quality_gate(sba, accepted, vec, X)
            if ok:
                accepted.append(sba)
                to_append.append(sba)
                pbar.update(1)

            if len(accepted) % CHECKPOINT_EVERY == 0 and to_append:
                # append newly accepted to disk (resume-safe)
                append_jsonl(OUTFILE, to_append)
                to_append = []
        # write stragglers
        if to_append:
            append_jsonl(OUTFILE, to_append)

        time.sleep(DELAY_BETWEEN_CALLS)

    # Final write to ensure file exists even if empty-run
    if not os.path.exists(OUTFILE):
        save_jsonl(OUTFILE, accepted)
    pbar.close()

    print(f"Saved: {OUTFILE} ({len(accepted)} SBAs)")

if __name__ == "__main__":
    load_dotenv()
    os.makedirs(OUTDIR, exist_ok=True)
    main()
