#!/usr/bin/env python3
"""Pick a working LLM brain for the mobileqa agent — by actually calling each provider.

Reads candidate providers from the environment (set by the workflow from repo secrets/vars),
probes each one with a real 1-token chat completion, and writes the first one that answers to
$GITHUB_ENV as MOBILEQA_LLM_BASE_URL / MOBILEQA_LLM_API_KEY / MOBILEQA_MODEL (+ vision model).
Prints a table of every provider tried and the exact failure, so a dead key is obvious.

Candidates, in order (each only if its key is present):
  1. EXPLICIT   MOBILEQA_LLM_BASE_URL + MOBILEQA_LLM_API_KEY (+ MOBILEQA_MODEL)   any OpenAI-compatible host
  2. GROQ       GROQ_API_KEY            https://api.groq.com/openai/v1              model auto-picked from /models
  3. GEMINI     GEMINI_API_KEY          https://generativelanguage.googleapis.com/v1beta/openai/  model auto-picked (flash)
  4. OPENROUTER OPENROUTER_API_KEY      https://openrouter.ai/api/v1                model auto-picked (free)
  5. CEREBRAS   CEREBRAS_API_KEY        https://api.cerebras.ai/v1                  model auto-picked
  6. ANTHROPIC  ANTHROPIC_API_KEY       handled natively by the agent (no base URL)
No winner -> nothing exported -> the agent runs its free heuristic brain.
"""
import json, os, sys, urllib.request, urllib.error

TIMEOUT = 20

def http(method, url, key, body=None):
    req = urllib.request.Request(url, method=method, data=(json.dumps(body).encode() if body else None))
    req.add_header("Authorization", f"Bearer {key}")
    req.add_header("Content-Type", "application/json")
    if "openrouter" in url:
        req.add_header("HTTP-Referer", "https://github.com/manan99991/mobileqa"); req.add_header("X-Title", "mobileqa")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.status, json.loads(r.read().decode() or "{}")

def list_models(base, key):
    try:
        _, data = http("GET", base.rstrip("/") + "/models", key)
        return [m.get("id", "") for m in data.get("data", [])]
    except Exception as e:
        return None, e

def pick(models, prefs):
    for p in prefs:
        for m in models:
            if p in m.lower():
                return m
    return models[0] if models else None

def probe(name, base, key, model):
    try:
        st, data = http("POST", base.rstrip("/") + "/chat/completions", key,
                        {"model": model, "messages": [{"role": "user", "content": "Reply with the single word OK."}], "max_tokens": 5})
        txt = (data.get("choices") or [{}])[0].get("message", {}).get("content", "")
        return True, f"{st} → {txt.strip()[:20]!r}"
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")[:160].replace("\n", " ")
        return False, f"HTTP {e.code}: {body}"
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"

def clean(v):
    return (v or "").strip().replace("\r", "").replace("\n", "")

def main():
    env = os.environ
    cands = []
    if clean(env.get("MOBILEQA_LLM_API_KEY")) and clean(env.get("MOBILEQA_LLM_BASE_URL")):
        cands.append(("explicit", clean(env["MOBILEQA_LLM_BASE_URL"]), clean(env["MOBILEQA_LLM_API_KEY"]), clean(env.get("MOBILEQA_MODEL")) or None, ["gpt-oss-120b", "llama-3.3-70b", "llama"]))
    if clean(env.get("GROQ_API_KEY")):
        cands.append(("groq", "https://api.groq.com/openai/v1", clean(env["GROQ_API_KEY"]), None, ["openai/gpt-oss-120b", "gpt-oss-120b", "llama-3.3-70b-versatile", "llama-4", "llama"]))
    if clean(env.get("GEMINI_API_KEY")):
        cands.append(("gemini", "https://generativelanguage.googleapis.com/v1beta/openai/", clean(env["GEMINI_API_KEY"]), None, ["flash-latest", "2.5-flash", "3-flash", "flash", "pro"]))
    if clean(env.get("OPENROUTER_API_KEY")):
        cands.append(("openrouter", "https://openrouter.ai/api/v1", clean(env["OPENROUTER_API_KEY"]), clean(env.get("OPENROUTER_MODEL")) or None, [":free"]))
    if clean(env.get("CEREBRAS_API_KEY")):
        cands.append(("cerebras", "https://api.cerebras.ai/v1", clean(env["CEREBRAS_API_KEY"]), None, ["gpt-oss-120b", "llama-3.3-70b", "llama"]))

    rows, winner = [], None
    for name, base, key, model, prefs in cands:
        if winner:
            rows.append((name, "-", "skipped (already have a brain)")); continue
        if not model:
            models = list_models(base, key)
            if isinstance(models, tuple):
                rows.append((name, "?", f"/models failed: {type(models[1]).__name__}: {str(models[1])[:120]}")); continue
            model = pick(models, prefs)
            if not model:
                rows.append((name, "?", f"/models returned {len(models)} models, none usable")); continue
        ok, why = probe(name, base, key, model)
        rows.append((name, model, ("OK " if ok else "FAIL ") + why))
        if ok:
            winner = (name, base, key, model)

    print("\n=== LLM brain selection ===")
    print(f"{'provider':<11} {'model':<34} result")
    for r in rows:
        print(f"{r[0]:<11} {r[1][:34]:<34} {r[2]}")
    if not cands:
        print("(no provider keys set — add GROQ_API_KEY / GEMINI_API_KEY / OPENROUTER_API_KEY / CEREBRAS_API_KEY, or MOBILEQA_LLM_BASE_URL + MOBILEQA_LLM_API_KEY)")

    gh_env = env.get("GITHUB_ENV")
    out = []
    if winner:
        name, base, key, model = winner
        vision = clean(env.get("MOBILEQA_VISION_MODEL")) or model
        no_vision = clean(env.get("MOBILEQA_NO_VISION")) or ("1" if name in ("groq", "cerebras") and "vision" not in model.lower() else "")
        out += [f"MOBILEQA_LLM_BASE_URL={base}", f"MOBILEQA_LLM_API_KEY={key}", f"MOBILEQA_MODEL={model}"]
        out += [f"MOBILEQA_NO_VISION=1"] if no_vision else [f"MOBILEQA_VISION_MODEL={vision}"]
        if clean(env.get("MOBILEQA_REASONING_EFFORT")): out.append(f"MOBILEQA_REASONING_EFFORT={clean(env['MOBILEQA_REASONING_EFFORT'])}")
        print(f"\nBRAIN: {name} / {model} ({'text-only' if no_vision else 'vision on'})")
    elif clean(env.get("ANTHROPIC_API_KEY")):
        print("\nBRAIN: anthropic (agent-native)")
    else:
        print("\nBRAIN: heuristic (no provider answered)")
    if gh_env and out:
        with open(gh_env, "a") as f:
            f.write("\n".join(out) + "\n")
    summary = env.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write("### QA brain\n\n| provider | model | result |\n|---|---|---|\n")
            for r in rows: f.write(f"| {r[0]} | {r[1]} | {r[2].replace('|','/')} |\n")
            f.write(f"\n**{('Using ' + winner[0] + ' / ' + winner[3]) if winner else 'No provider answered — heuristic brain'}**\n")

if __name__ == "__main__":
    main()
