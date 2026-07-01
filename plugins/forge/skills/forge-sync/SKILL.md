---
name: forge-sync
description: The read/edit/validate/deploy loop that keeps local forge entity JSON in sync with the Amigo Platform, entirely via `forge platform ...`. Use when a forge binary is on PATH and the project has .env.platform.* files or a local/<env>/entity_data tree, and the user asks to read remote entities down (`forge platform <entity> get`), deploy/publish/push their changes up (`forge platform push`, dry-run then --apply), review a dry-run plan before applying, or reconcile local JSON with the Platform including the local/<env>/.platform_id_map.json local-to-Platform UUID map. Platform-only; no legacy backend.
---

# Forge Sync

The round-trip loop between local entity JSON and the Amigo Platform, run entirely through `forge platform ...`: read remote state down, edit files locally, validate, then deploy changes back up with `forge platform push`.

## When to use

Use this skill when the user says things like:

- "read/bring the latest agents/context graphs/services down to local"
- "push my changes" / "publish" / "deploy my entity changes" to the Platform
- "platform push" / "do a dry run first, then apply"
- "what does the id map / .platform_id_map.json do?"
- "reconcile my local JSON with what's on the Platform"

Observable preconditions: a `forge` binary on `PATH`, and a project with `.env.platform.<env>` files and/or a `local/<env>/entity_data/<type>/*.json` tree.

### When NOT to use -> use a sibling instead

- Deciding *what* the agent should be / scoping before any files exist -> use **/forge-agent-design** (read first when scoping).
- Generating or hand-writing the entity JSON content itself -> use **/forge-build-agent**.
- Only checking local files for errors (no read/deploy) -> use **/forge-validate**.
- Testing behavior *after* a push (regression sims, interactive sessions) -> use **/forge-simulate**.

This skill owns the transport loop; it hands validation to **/forge-validate** and post-push testing to **/forge-simulate**.

## Preflight: config + auth

Every command here talks to the Platform API, so confirm config and auth before any transport.

Config is read from the environment and env files. Precedence (highest wins): process env vars > `.env.platform.<env>` in the current directory. Required values are `PLATFORM_API_URL`, `PLATFORM_WORKSPACE_ID`, and either `PLATFORM_API_KEY` (static key) or `IDENTITY_URL` (device-code login, RFC 8628).

```bash
# Confirm you are authenticated to the Platform for this env.
forge auth status --platform --env staging

# If not logged in: device-code login prints a browser URL to approve
# (static API key is a no-op confirm).
forge auth login --platform --env staging
```

## Workflow

Replace `staging` with the target `--env`. `forge platform push` supports the entity types `agent`, `context_graph`, and `service`. Individual read/author commands (`forge platform <entity> ...`) cover `agent`, `context-graph`, `service`, `skill`, and `function`.

### 1. Read remote -> edit local

There is no bulk pull-to-disk command. Read individual entities from the Platform and edit the local JSON under `local/<env>/entity_data/<type>/`.

```bash
# List what exists on the Platform, then fetch one entity by id.
forge platform agent list --env staging
forge platform agent get 00000000-0000-0000-0000-000000000000 --env staging

# Same pattern for the other read/author entities.
forge platform context-graph list --env staging
forge platform service get 00000000-0000-0000-0000-000000000000 --env staging
```

Edit the JSON under `local/staging/entity_data/<type>/*.json` (for example `local/staging/entity_data/agent/*.json`). The agent's own JSON carries its identity and instructions — there is no separate entity for that. For generating or authoring entity content, hand off to **/forge-build-agent**.

### 2. Validate before deploying

Always validate local files before a push. Hand this off to **/forge-validate**; the core command is:

```bash
forge validate --entity-type agent --env staging
# or validate everything
forge validate --all --env staging
```

`validate` is local-only (no API, no auth). On `validate`, `-e` means `--entity-type`, so always spell out `--env` for the environment.

### 3. Deploy local -> Platform (`forge platform push`)

`forge platform push` is the deploy path. It is **dry-run by default** and only mutates the Platform when you add `--apply`. It supports `agent`, `context_graph`, and `service`, and manages the local-to-Platform id map.

```bash
# Dry run: review the plan. On push, -e is --entity-type, so use long --env.
forge platform push --entity-type agent --env staging

# All supported types in order (agent, context_graph, service).
forge platform push --all --env staging

# Apply after reviewing the plan.
forge platform push --entity-type agent --env staging --apply
```

WARNING: on `push`, the `-e` short flag is `--entity-type` (not env). Always use the long `--env` flag to select the environment, e.g. `forge platform push -e agent --env staging`.

### 4. Test after push

Once changes are live on the Platform, hand off to **/forge-simulate** to run regression sims or interactive sessions against the updated service.

## The .platform_id_map.json

`forge platform push` maintains `local/<env>/.platform_id_map.json`, which maps your local entity identifiers to their Platform UUIDs. This is how a re-push knows to update an existing Platform entity instead of creating a duplicate.

- Do not hand-edit it unless you know exactly why.
- Keep it alongside `local/<env>/entity_data/` so pushes stay idempotent.
- If it is missing, a push may create new entities rather than update existing ones.

## Safety

- **Read-only first.** `forge platform <entity> list` / `get` and `forge validate` do not mutate the Platform. Start there, then a dry-run `forge platform push`.
- **Dry-run before apply.** `forge platform push` is dry-run by default. Review the printed plan, then re-run with `--apply` only when the user explicitly asks to publish/deploy.
- **Confirm the env.** Double-check `--env` (e.g. `staging`) before any `--apply`; pushing to the wrong environment is a real mutation.
- **Never commit real data.** Do not write real customer/org names, workspace IDs, phone numbers, emails, addresses, or URLs into notes, commits, PRs, or examples. Use synthetic placeholders only (`Acme Corp` / `Example Health`, `test-org`, `user@example.com`, `555-010-1234`, `00000000-0000-0000-0000-000000000000`).
