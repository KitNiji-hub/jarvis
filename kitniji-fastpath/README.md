# KitNiji Jarvis Fast Pipeline

This branch is based on upstream `isair/jarvis` main commit `d22ed8b975792842dc09e49861f31a39cbb302a6` and contains a reversible latency-optimization kit for the local stack:

- Chat: `gpt-oss:20b`
- Fast intent/router/planner: `gemma4:e2b`
- Embeddings: `nomic-embed-text`
- STT: Whisper tiny on CUDA
- TTS: Piper

## Why this exists

Observed simple-knowledge latency was ~26–33 seconds even though direct Ollama inference was much faster. The current Jarvis pipeline can spend time in intent/routing/planning/memory before the final chat-model call. In particular, the LLM tool router prompt encourages web tools for explanations, the simple-query planner bypass only covers queries up to 8 words, and the planner normally runs on the CHAT tier.

## What Phase 1 changes

1. Stable general-knowledge questions may route to `none` instead of automatically selecting `webSearch + fetchWebPage`.
2. The existing reply-only planner bypass expands from 8 to 12 words.
3. Planning uses the FAST tier so routing/planning stays on `gemma4:e2b` and the main `gpt-oss:20b` model is reserved for the final answer.
4. The benchmark config disables optional memory/tool-result digest passes and caps long agent loops while testing.

Phase 1 intentionally does **not** rewrite Jarvis architecture. It preserves the stock paths for memory, tools, web, and multi-step work and only removes obvious overhead from simple requests.

## Run it

Clone this branch:

```powershell
git clone -b kitniji/fast-pipeline https://github.com/KitNiji-hub/jarvis.git
cd jarvis
```

Apply the source changes:

```powershell
.\kitniji-fastpath\apply-fastpath.ps1
```

Review them before committing:

```powershell
git diff
```

Apply the benchmark config (it creates a timestamped backup first):

```powershell
.\kitniji-fastpath\configure-fastpath.ps1
```

Then build/run Jarvis from this checkout using the repository's normal Windows/source instructions.

## Benchmark prompts

Run each three times after warm-up and record Heard → Intent, Intent → Tools/Generate, Generate → Answer, and total time.

1. `Jarvis, say only the word ready.`
2. `Jarvis, explain why the sky is blue in two sentences.`
3. `Jarvis, what time is it?`
4. `Jarvis, what's the weather right now?`
5. `Jarvis, take a screenshot.`
6. `Jarvis, remember that my benchmark phrase is purple pineapple.`
7. `Jarvis, what is my benchmark phrase?`
8. `Jarvis, tell me tomorrow's weather, then find local events for tomorrow, then recommend which events suit the weather.`

Desired sky-question route:

```text
Whisper
  -> intent
  -> FAST router = none
  -> planner skipped
  -> no memory enrichment
  -> gpt-oss:20b final answer
  -> Piper
```

## Rollback

The source patcher creates `*.kitniji-backup` copies before touching the three source files. The config helper creates a timestamped `config.json.backup-*` file before changing settings.

You can also reset the checkout with Git after inspecting the diff.

## Phase 2 after timing data

- deterministic direct commands for time/date and other safe local facts
- screenshot/OCR error-path diagnosis
- explicit per-stage timing instrumentation
- conditional/lazy memory retrieval instead of fail-open enrichment
- better tool-router relevance tests
- preserving multi-step planning while bypassing it for ordinary conversation
