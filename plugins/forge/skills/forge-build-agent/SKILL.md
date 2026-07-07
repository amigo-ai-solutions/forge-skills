---
name: forge-build-agent
description: Stand up an Amigo agent or service end-to-end with the forge CLI, building entities in cascade order - functions (deterministic reducible work), a single-state context_graph, the agent (its identity/voice lives here), skills (must-be-exact bounded concerns), a service (wiring), and a pinned version-set. Use when a forge binary is on PATH and the user asks to build, stand up, scaffold, author, create, or wire an Amigo agent, service, context-graph, skill, or function - either directly on the Platform (forge platform ... create/register) or by editing JSON under local/<env>/entity_data and pushing it with forge platform push, then binding versions with forge platform version-set upsert.
---

# Forge Build Agent

The concrete "stand up an agent/service with forge" workflow. It builds entities in the order the design cascade implies, so each layer rests on the one below it.

## When to use

Use this skill when the user says things like:

- "Build / stand up / scaffold a new Amigo agent (or service) with forge."
- "Create a context-graph / agent / skill / function on the Platform."
- "Wire these into a service and pin the versions."
- "I have JSON under `local/staging/entity_data` - push it and bind a version-set."

### When NOT to use - route to a sibling instead

- Still deciding scope, boundaries, or whether something should be an agent vs. a skill vs. a function -> read `/forge-agent-design` first; it hands off here once the shape is settled.
- Only checking that local entity JSON is well-formed -> use `/forge-validate`.
- Only pulling remote state down or pushing local edits up (no new entities to author) -> use `/forge-sync`.
- Regression, parity, or a promotion gate before shipping -> use `/forge-simulate`.

## Cascade build order

Build bottom-up so each entity can reference the ones beneath it:

1. Preflight: platform env file + auth.
2. Push reducible, must-be-deterministic work into `function`s.
3. Start with a single-state `context_graph`.
4. Create the `agent` — author its identity/voice in the agent's own global instructions.
5. Isolate must-be-exact or bounded concerns as `skill`s and route to them from the graph.
6. Bind everything into a `service`.
7. Pin versions with a writable `version-set` (e.g. `candidate`).

Two authoring paths reach the same result. Pick one:

- **Path A - API-first**: create entities directly on the Platform. Fastest for a fresh build or quick iteration.
- **Path B - Files-first**: edit JSON on disk, validate, then push. Best when the work is reviewable/diffable, lives in source control, or already exists under `local/<env>/entity_data`.

## Workflow

Read-only first: run `list`/`get`/`status` and dry-run pushes before any mutation. Use placeholders below (`--env staging`, org `Acme Corp`, workspace `test-org`, UUID `00000000-0000-0000-0000-000000000000`) and substitute the user's real values at runtime.

### Step 1 - Preflight (both paths)

Config comes from an env file, not a profile store. The Platform reads `.env.platform.<env>` in the working directory (process env vars also apply). Confirm auth against the Platform identity service.

```bash
# A .env.platform.staging in the cwd supplies the required config, e.g.:
#   PLATFORM_API_URL=https://api.platform.amigo.ai
#   PLATFORM_WORKSPACE_ID=00000000-0000-0000-0000-000000000000
#   IDENTITY_URL=https://api.platform.amigo.ai          # device-code auth (RFC 8628)
#   # or, for static-key auth instead of IDENTITY_URL:
#   PLATFORM_API_KEY=<static key>

# Authenticate against the Platform identity service (device-code prints a browser URL;
# a static PLATFORM_API_KEY is a no-op confirm)
forge auth login --platform --env staging
forge auth status --platform --env staging
```

Required config: `PLATFORM_API_URL`, `PLATFORM_WORKSPACE_ID`, and either `PLATFORM_API_KEY` (static) or `IDENTITY_URL` (device-code). You can also override the workspace per call with `--workspace <id>`.

---

### Path A - API-first (create directly on the Platform)

#### Step 2A - Push reducible work into deterministic functions

Isolate anything that must be exact/repeatable (lookups, calculations, formatting) as a `function`, then confirm it resolves. `--input-schema` takes a path to a JSON file, so write the schema out first.

```bash
cat > ./lookup_order_status.schema.json <<'JSON'
{"type":"object","properties":{"order_id":{"type":"string"}},"required":["order_id"]}
JSON
forge platform function register --name lookup_order_status \
  --description "Deterministic order-status lookup" \
  --input-schema ./lookup_order_status.schema.json
forge platform function list --json
forge platform function test lookup_order_status --input '{"order_id":"A-1001"}' --json
```

#### Step 3A - Start with a single-state context_graph

Begin minimal - one state - and iterate with `create-version`.

```bash
forge platform context-graph create --name "Acme Support Graph" --description "Single-state starting point"
# note the returned <graph-id>, then iterate:
forge platform context-graph create-version <graph-id> --file ./graph_v2.json
forge platform context-graph list-versions <graph-id> --json
```

#### Step 4A - Create the agent (identity/voice lives here)

The agent carries its own identity, voice, and global instructions — author them here (in
the agent's definition and versions), reinforced by the context graph. Identity is not a
separate entity.

> **How to author the agent's instructions and design context-graph states** — identity's
> ~70-80% rule, action guidelines vs. boundary constraints, minimal viable constraint, the
> four state types, naming, and lean globals — see
> `reference/agent-context-graph-authoring.md`.

```bash
forge platform agent create --name "Acme Support Agent" --description "Handles order and account questions"
forge platform agent list --json
# iterate on behavior with versions:
forge platform agent create-version <agent-id> --file ./agent_v2.json
```

#### Step 5A - Isolate bounded concerns as skills, route from the graph

Author must-be-exact or narrowly-scoped concerns as `skill`s, test them, then reference them from the context-graph states that should invoke them.

> **A `skill` is a single Anthropic-model system prompt that uses tools.** For how to write
> that system prompt (role, clear instructions, examples, output format), define its tools,
> and choose/tune a model tier, see
> `reference/skill-prompting.md`.

```bash
forge platform skill create --file ./verify_identity_skill.json
forge platform skill test <skill-id> --body '{"input":"sample caller turn"}'
forge platform skill references <skill-id>
```

#### Step 6A - Bind everything into a service

A service wires a specific agent + context-graph together.

```bash
forge platform service create --name "Acme Support Service" \
  --agent-id <agent-id> --context-graph-id <graph-id> \
  --description "Support line for Acme Corp"
forge platform service get <service-id>
```

Optionally attach voice/escalation presets:

```bash
forge platform service voice-config <service-id> --get
forge platform service escalation-policy <service-id> --get
```

#### Step 7A - Pin versions with a version-set

Pin the agent + context-graph versions into a writable, named version set (use a name you own, e.g. `candidate`). Do NOT target the `edge` set: it auto-tracks the latest versions and the CLI refuses to modify it (`cannot modify the 'edge' version set`). Version-set mutations are dry-run by default; re-run with `--apply` once the plan looks right.

```bash
# dry run first
forge platform version-set upsert <service-id> candidate --agent-version 1 --context-graph-version 1
# then commit
forge platform version-set upsert <service-id> candidate --agent-version 1 --context-graph-version 1 --apply
forge platform version-set list <service-id> --json
# optionally promote the vetted set into your release set (also dry-run by default):
forge platform version-set promote <service-id> candidate release --apply
```

---

### Path B - Files-first (edit JSON on disk, then push)

#### Step 2B - Author entities on disk

There is no bulk pull-to-disk command. Fetch current entities with `forge platform <entity> get` when you need them, then write/edit the JSON under `local/<env>/entity_data/<type>/`.

```bash
forge platform agent get 00000000-0000-0000-0000-000000000000 --env staging
```

Entities live under `local/staging/entity_data/<type>/*.json` (types: `context_graph`, `agent`, `skill`, `service`, ... ). The local->Platform UUID map in `local/staging/.platform_id_map.json` is managed by `forge platform push` - do not hand-edit it.

#### Step 3B - Author the cascade on disk

Edit the JSON files in cascade order (functions -> single-state context_graph -> agent -> skills routed from the graph -> service). Keep the graph minimal to start.

#### Step 4B - Validate

```bash
forge validate --all --env staging
# or a single type:
forge validate --entity-type context_graph --env staging
```

Hand off to `/forge-validate` if you need to drill into validation errors.

#### Step 5B - Push (dry run, then apply)

Push is dry-run by default. On `push`, `-e` means `--entity-type`, so always use the long `--env` flag.

```bash
# preview the plan
forge platform push --all --env staging
# commit it
forge platform push --all --env staging --apply
```

`push` writes/updates `.platform_id_map.json` so local entities keep their Platform UUIDs across pushes.

#### Step 6B - Pin the version-set

Same as Step 7A - pin a writable named set (not `edge`), dry run, then `--apply`:

```bash
forge platform version-set upsert <service-id> candidate --agent-version 1 --context-graph-version 1
forge platform version-set upsert <service-id> candidate --agent-version 1 --context-graph-version 1 --apply
```

---

### Step 9 - Verify and hand off

- Confirm the service resolves its tools: `forge platform tool-test resolve --service-id <service-id>`.
- Before shipping, gate on a regression/parity run -> `/forge-simulate`.
- To keep local and remote in step afterward -> `/forge-sync`.

## Safety

- Read-only first: prefer `list`, `get`, `status`, `validate`, dry-run `push`, and dry-run `version-set` before mutating.
- Mutations only on explicit request: `forge platform push` and `forge platform version-set upsert/promote/rollback` change remote state only when you pass `--apply`; `... delete` prompts unless you pass `--yes`. Do not add `--apply`/`--yes` unless the user asked to commit the change.
- Synthetic data only for any test/simulation input - never real caller data.
- Never write real customer or organization names, workspace IDs, phone numbers, emails, addresses, or URLs into JSON files, notes, commits, or PRs. Use placeholders (`Acme Corp`, `test-org`, `user@example.com`, `555-010-1234`, `00000000-0000-0000-0000-000000000000`).
- `.platform_id_map.json` is managed by `push`; do not hand-edit it.
