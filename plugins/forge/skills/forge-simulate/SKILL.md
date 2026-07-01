---
name: forge-simulate
description: Regression-test, simulate, and smoke-test an Amigo agent before release, then prove parity and gate the cutover on the Amigo Platform (Go forge binary). Use when the user asks to run sims or regression sims against a service, simulate conversations, replay/step through controlled turns, inspect a simulation session, view the coverage graph, prove parity before promoting a version-set, compare an edge version-set to release, or make a GO/NO-GO or rollback decision; when a forge binary is on PATH and a service has an edge and release version-set. Synthetic data only.
---

# Forge Simulate

The regression / eval + parity-gate + rollback step: prove parity before cutover, keep the fallback, and define the rollback. This is the Go / Platform surface (`api.platform.amigo.ai`). It does NOT use `poetry run forge` (that is the older Python CLI) and does NOT use the deferred `sim smoke-test` / `sim run-*` / `sim session-create` / `sim session-step` / `sim session-recommend` commands, which are not implemented in this binary.

## When to use

Literal task phrases this skill should fire on:

- "run regression sims against this service before we ship"
- "smoke-test / simulate the agent"
- "prove parity between the edge and release version-sets"
- "is this a GO or NO-GO for the cutover?"
- "promote edge to release" / "cut over the new version"
- "roll back the last promotion"
- "step through a controlled conversation and score it"
- "show me the coverage graph / which paths the sims covered"

Observable preconditions: a `forge` binary on `PATH`; a configured Platform profile — a `.env.platform.<env>` file (or `.env.<env>`) with `PLATFORM_API_URL`, `PLATFORM_WORKSPACE_ID`, and either `PLATFORM_API_KEY` or `IDENTITY_URL` — verified with `forge auth status --platform`; a service that already has an `edge` version-set (the candidate) and a `release` version-set (the live fallback).

### When NOT to use -> use a sibling instead

- Scoping or designing the agent (what topics, tools, behaviors) -> use **/forge-agent-design** (read first when scoping; it hands off here).
- Editing the agent/context-graph/service and building the entity JSON -> use **/forge-build-agent**.
- Checking local entity files for errors before pushing -> use **/forge-validate**.
- Pushing local entities to Platform or pulling remote to local (deploying versions) -> use **/forge-sync** or **/forge-build-agent**.

Use this skill only for the simulate -> parity-gate -> promote/rollback loop against an already-deployed service that has candidate (`edge`) and live (`release`) version-sets.

## Workflow

All commands are read-only except `version-set promote` / `version-set rollback`, which are dry-run until you add `--apply`. Use synthetic scenarios and personas only — never real caller data.

Use a real service UUID in place of `00000000-0000-0000-0000-000000000000` and set `--env` to your profile or label (examples use `staging`).

### 1. Confirm access and the two version-sets

```bash
# Confirm you are authenticated against the Platform for this env.
# (Platform config is read from .env.platform.<env> or .env.<env>.)
forge auth status --platform --env staging

# The service must have both a candidate (edge) and a live (release) version-set.
forge platform version-set list 00000000-0000-0000-0000-000000000000 --env staging --json
```

`edge` is a built-in version-set that auto-tracks the latest pushed agent/context-graph
versions, so it always exists once the service has versions and is **immutable** — you
cannot `upsert` it or `promote` into it (`cannot modify the 'edge' version set`). Simulate
against `edge` to test your latest pushed work. To test a specific pinned combination of
versions instead, pin a writable named set (see **/forge-build-agent**) and use its name
wherever these steps use `edge`.

### 2. Multi-scenario regression (bridge)

Run a batch of synthetic scenarios against the service. Rule of thumb: about 10 sims per topic for the safety-critical and core behaviors you care about, so raise `--num-scenarios` accordingly.

```bash
forge platform sim bridge \
  --service-id 00000000-0000-0000-0000-000000000000 \
  --objective "Caller asks to reschedule an appointment and confirm the new time" \
  --num-scenarios 10 \
  --max-turns 2 \
  --env staging \
  --json
```

`sim bridge --json` returns the generated scenarios and their per-scenario results inline.
To drill into an individual session or see which conversation paths were covered, use the
session inspection (step 4) and the coverage graph (step 5).

> The `forge platform sim status` / `summary` / `sample` / `points` commands belong to the
> separate VoiceSim batch-tuning surface started by `forge platform sim create` — they do
> not read `sim bridge` runs.

### 3. Controlled interactive turns (deterministic replay)

For a scripted, turn-by-turn check of a specific flow, open a run and drive a session by hand. This is the `simulation` surface (not `sim`).

```bash
# Open a run (optionally pin it to the candidate branch/version-set).
forge platform simulation run create --service-id 00000000-0000-0000-0000-000000000000 --branch edge --env staging --json

# Start a session inside that run.
forge platform simulation session create \
  --run-id <run-id> \
  --service-id 00000000-0000-0000-0000-000000000000 \
  --branch edge \
  --caller-id 555-010-1234 \
  --env staging --json

# Feed synthetic caller turns one at a time.
forge platform simulation session step --session-id <session-id> --text "I need to reschedule my appointment" --env staging --json
forge platform simulation session step --session-id <session-id> --text "Wednesday at 3pm works" --emotion calm --valence positive --env staging --json

# Optionally branch to alternate replies, then score the session.
forge platform simulation session fork  --session-id <session-id> --alternatives '["Yes","No"]' --env staging --json
forge platform simulation session score --session-id <session-id> --score 4 --rationale "Confirmed the new time and read it back" --env staging --json

# Close out the run.
forge platform simulation run complete --run-id <run-id> --env staging --json
```

### 4. Inspect a session

```bash
forge platform sim session-observe <session-id> --env staging
forge platform sim session-intelligence <session-id> --env staging
```

### 5. Coverage graph

See which conversation states and paths the sims exercised — use this to spot topics with too little coverage.

```bash
forge platform simulation graph show  --service-id 00000000-0000-0000-0000-000000000000 --run-id <run-id> --include-turns --env staging --json
forge platform simulation graph paths --service-id 00000000-0000-0000-0000-000000000000 --run-id <run-id> --env staging --json
```

### 6. Parity gate: compare edge to release

Before promoting, diff the two version-sets and confirm the `edge` sims match or beat `release` on your core and safety behaviors.

```bash
forge platform version-set diff 00000000-0000-0000-0000-000000000000 edge release --env staging --json
```

GO / NO-GO rule of thumb: for each topic, ~10 sims on the safety-critical and core behaviors, `edge` at parity-or-better with `release`, no regression in the coverage graph. If any of that fails, it is a NO-GO — fix on `edge` and re-run from step 2. Do not promote.

### 7. Cut over (promote) — mutation, requires --apply

Only when the parity gate passes and the user explicitly asks to cut over. Dry-run first; a backup of the target is kept by default (do not pass `--no-backup`).

```bash
# Dry-run: shows what promoting edge -> release would do.
forge platform version-set promote 00000000-0000-0000-0000-000000000000 edge release --env staging

# Apply the cutover.
forge platform version-set promote 00000000-0000-0000-0000-000000000000 edge release --env staging --apply
```

### 8. Rollback — keep the fallback ready

If the promoted version misbehaves, roll `release` back to the retained backup. Dry-run first, then `--apply`.

```bash
forge platform version-set rollback 00000000-0000-0000-0000-000000000000 --env staging
forge platform version-set rollback 00000000-0000-0000-0000-000000000000 --env staging --apply
```

## Hand-off

- Scoping what to test (topics, behaviors, tools) -> **/forge-agent-design**.
- Changing the agent/context-graph and deploying new versions of the entities under test -> **/forge-build-agent** and **/forge-sync**.

## Safety

- Read-only first. `sim bridge`, `simulation session`/`run`/`graph`, `sim session-observe`/`session-intelligence`, and `version-set list`/`get`/`diff` do not change anything.
- Mutations only on explicit request. `version-set upsert`, `version-set promote`, and `version-set rollback` are dry-run by default and change the live service only when you add `--apply` — run them with `--apply` solely when the user asks to cut over or roll back, after the parity gate passes.
- Keep the fallback. Promote keeps a backup of `release` unless you pass `--no-backup` (do not) so `version-set rollback ... --apply` can restore it.
- Synthetic data only. Use invented scenarios, personas, and placeholder caller ids (e.g. 555-010-1234); never feed real caller conversations, PII, or customer identifiers into a simulation.
- Never write real customer or organization names, workspace ids, phone numbers, emails, or URLs into notes, commits, or PRs.
