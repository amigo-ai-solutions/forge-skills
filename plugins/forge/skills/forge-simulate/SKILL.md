---
name: forge-simulate
description: Regression-test, simulate, and smoke-test an Amigo agent before release, then prove parity and gate the cutover on the Amigo Platform (Go forge binary). Use when the user asks to run sims or regression sims against a service, simulate conversations, replay/step through controlled turns, inspect a simulation session, view the coverage graph, prove parity before promoting a version-set, compare a candidate version-set to release, or make a GO/NO-GO or rollback decision; when a forge binary is on PATH and a service has a release version-set. Synthetic data only.
---

# Forge Simulate

The regression / eval + parity-gate + rollback step: prove parity before cutover, keep the fallback, and define the rollback. Every command is `forge platform ...` against the Amigo Platform (`api.platform.amigo.ai`).

## When to use

Literal task phrases this skill should fire on:

- "run regression sims against this service before we ship"
- "smoke-test / simulate the agent"
- "prove parity between a candidate and the release version-set"
- "is this a GO or NO-GO for the cutover?"
- "promote a candidate to release" / "cut over the new version"
- "roll back the last promotion"
- "step through a controlled conversation and score it"
- "show me the coverage graph / which paths the sims covered"

Observable preconditions: a `forge` binary on `PATH`; a configured Platform profile — a `.env.platform.<env>` file with `PLATFORM_API_URL`, `PLATFORM_WORKSPACE_ID`, and either `PLATFORM_API_KEY` or `IDENTITY_URL` — verified with `forge auth status --platform`; a service that has a `release` version-set (the live set). To test a specific version combination, pin it into a writable named set such as `candidate` (see step 1).

### When NOT to use -> use a sibling instead

- Scoping or designing the agent (what topics, tools, behaviors) -> use **/forge-agent-design** (read first when scoping; it hands off here).
- Editing the agent/context-graph/service and building the entity JSON -> use **/forge-build-agent**.
- Checking local entity files for errors before pushing -> use **/forge-validate**.
- Pushing local entities to Platform or pulling remote to local (deploying versions) -> use **/forge-sync** or **/forge-build-agent**.

Use this skill only for the simulate -> parity-gate -> promote/rollback loop against an already-deployed service with a `release` version-set (and, optionally, a writable `candidate` set you pin for testing).

## Workflow

All commands are read-only except `version-set promote` / `version-set rollback`, which are dry-run until you add `--apply`. Use synthetic scenarios only — never real caller data.

Use a real service UUID in place of `00000000-0000-0000-0000-000000000000` and set `--env` to your profile or label (examples use `staging`).

### 1. Confirm access and the two version-sets

```bash
# Confirm you are authenticated against the Platform for this env.
# (Platform config is read from .env.platform.<env>.)
forge auth status --platform --env staging

# List the service's version-sets. `release` is the live set the service serves.
forge platform version-set list 00000000-0000-0000-0000-000000000000 --env staging --json
forge platform version-set get  00000000-0000-0000-0000-000000000000 release --env staging --json
```

**Version-set model.** `release` is the live set the service serves. To test a specific
agent + context-graph combination, pin it into a **writable named set** (e.g. `candidate`)
with `forge platform version-set upsert <service-id> candidate -a <agent-ver> -g <graph-ver>`
(see **/forge-build-agent**). **`edge` is a reserved name** — the CLI refuses to `upsert` it
or `promote` into it (`cannot modify the 'edge' version set`), and it is not guaranteed to
exist on a service, so don't target it. Simulate against `release` (current live behavior),
or pin and target a `candidate` (step 3 uses `--branch candidate`).

### 2. Multi-scenario regression (bridge)

Run a batch of synthetic scenarios against the service. **Sample enough to see the distribution, not one draw:** a non-deterministic stage needs roughly **30 samples** to characterize its output distribution — running a multi-branch agent 3 times tells you almost nothing. Use **≥10 sims per topic** as the GO/NO-GO gate, and **~30+** when you are *characterizing* a behavior or *comparing* `edge` vs `release` at parity. Raise `--num-scenarios` accordingly.

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
forge platform simulation run create --service-id 00000000-0000-0000-0000-000000000000 --branch candidate --env staging --json

# Start a session inside that run.
forge platform simulation session create \
  --run-id <run-id> \
  --service-id 00000000-0000-0000-0000-000000000000 \
  --branch candidate \
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

### 6. Parity gate: compare candidate to release

Before promoting, diff the two version-sets and confirm the `candidate` sims match or beat `release` on your core and safety behaviors.

```bash
forge platform version-set diff 00000000-0000-0000-0000-000000000000 candidate release --env staging --json
```

GO / NO-GO rule of thumb: for each topic, ~10 sims on the safety-critical and core behaviors (use ~30+ when the call is close or you're proving `candidate`↔`release` parity — see step 2), `candidate` at parity-or-better with `release`, no regression in the coverage graph. If any of that fails, it is a NO-GO — fix the candidate and re-run from step 2. Do not promote.

### 7. Cut over (promote) — mutation, requires --apply

Only when the parity gate passes and the user explicitly asks to cut over. Dry-run first; a backup of the target is kept by default (do not pass `--no-backup`).

```bash
# Dry-run: shows what promoting candidate -> release would do.
forge platform version-set promote 00000000-0000-0000-0000-000000000000 candidate release --env staging

# Apply the cutover.
forge platform version-set promote 00000000-0000-0000-0000-000000000000 candidate release --env staging --apply
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
- Synthetic data only. Use invented scenarios and placeholder caller ids (e.g. 555-010-1234); never feed real caller conversations, PII, or customer identifiers into a simulation.
- Never write real customer or organization names, workspace ids, phone numbers, emails, or URLs into notes, commits, or PRs.
