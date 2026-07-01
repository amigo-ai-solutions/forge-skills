---
name: forge-sync
description: The pull/edit/validate/push loop that keeps local forge entity files in sync with the Amigo Platform. Use when a forge binary is on PATH and the project has .env.platform.* files or a local/<env>/entity_data tree, and the user asks to pull/sync entities down (sync-to-local / stl), push/publish/deploy their changes up (sync-to-remote / str, or platform push), review a dry-run plan before applying, run --apply to commit changes, or reconcile local JSON with the Platform including the .platform_id_map.json local-to-Platform UUID map.
---

# Forge Sync

The round-trip loop between local entity JSON and the Amigo Platform: pull remote state down, edit files locally, validate, then push changes back up.

## When to use

Use this skill when the user says things like:

- "pull the latest agents/context graphs/services down to local"
- "sync-to-local" / "stl" / "sync-to-remote" / "str"
- "push my changes" / "publish" / "deploy my entity changes" to the Platform
- "platform push" / "do a dry run first, then apply"
- "what does the id map / .platform_id_map.json do?"
- "reconcile my local JSON with what's on the Platform"

Observable preconditions: a `forge` binary on `PATH`, and a project with `.env.platform.<env>` files and/or a `local/<env>/entity_data/<type>/*.json` tree.

### When NOT to use -> use a sibling instead

- Deciding *what* the agent should be / scoping before any files exist -> use **/forge-agent-design** (read first when scoping).
- Generating or hand-writing the entity JSON content itself -> use **/forge-build-agent**.
- Only checking local files for errors (no pull/push) -> use **/forge-validate**.
- Testing behavior *after* a push (regression sims, interactive sessions) -> use **/forge-simulate**.

This skill owns the transport loop; it hands validation to **/forge-validate** and post-push testing to **/forge-simulate**.

## Preflight: config + auth

Sync commands talk to the Platform API, so confirm config and auth before any transport.

Config is read from the environment and env files. Precedence (highest wins): process env vars > `.env.platform.<env>` in the current directory > `.env.<env>`. Required values are `PLATFORM_API_URL`, `PLATFORM_WORKSPACE_ID`, and either `PLATFORM_API_KEY` (static key) or `IDENTITY_URL` (device-code login, RFC 8628).

```bash
# Confirm you are authenticated to the Platform for this env.
forge auth status --platform --env staging

# If not logged in: device-code login prints a browser URL to approve
# (static API key is a no-op confirm).
forge auth login --platform --env staging
```

## Workflow

Replace `staging` with the target `--env` and `<type>` with an entity type
(`agent`, `context_graph`, `dynamic_behavior_set`, `metric`, `persona`, `scenario`,
`service`, `tool`, `unit_test_set`, `unit_test`, `user_dimension`).

### 1. Pull remote -> local

```bash
# One entity type.
forge sync-to-local --entity-type agent --env staging

# Alias 'stl' is equivalent.
forge stl --entity-type context_graph --env staging

# Everything.
forge sync-to-local --all --env staging
```

Files land under `local/<env>/entity_data/<type>/*.json` (for example
`local/staging/entity_data/agent/*.json`).

### 2. Edit locally

Edit the JSON under `local/staging/entity_data/<type>/`. For generating or
authoring entity content, hand off to **/forge-build-agent**.

### 3. Validate before pushing

Always validate local files before a push. Hand this off to **/forge-validate**;
the core command is:

```bash
forge validate --entity-type agent --env staging
# or validate everything
forge validate --all --env staging
```

`validate` is local-only (no API, no auth). On `validate`, `-e` means
`--entity-type`, so always spell out `--env` for the environment.

### 4. Push local -> remote

Two push mechanisms. Both are **dry-run by default** and only mutate the
Platform when you add `--apply`.

**Option A - bulk plan/apply (`platform push`, preferred).** Supports
`agent`, `context_graph`, and `service`, and manages the local-to-Platform id map.

```bash
# Dry run: review the plan. On push, -e is --entity-type, so use long --env.
forge platform push --entity-type agent --env staging

# All three supported types in order (agent, context_graph, service).
forge platform push --all --env staging

# Apply after reviewing the plan.
forge platform push --entity-type agent --env staging --apply
```

WARNING: on `push`, the `-e` short flag is `--entity-type` (not env). Always use
the long `--env` flag to select the environment, e.g.
`forge platform push -e agent --env staging`.

**Option B - legacy per-type (`sync-to-remote` / `str`).** Covers all entity
types; also dry-run by default.

```bash
# Dry run: preview the change.
forge sync-to-remote --entity-type persona --env staging

# Alias 'str', and --apply to commit.
forge str --entity-type persona --env staging --apply
```

### 5. Test after push

Once changes are live on the Platform, hand off to **/forge-simulate** to run
regression sims or interactive sessions against the updated service.

## The .platform_id_map.json

`forge platform push` maintains `local/<env>/.platform_id_map.json`, which maps
your local entity identifiers to their Platform UUIDs. This is how a re-push
knows to update an existing Platform entity instead of creating a duplicate.

- Do not hand-edit it unless you know exactly why.
- Keep it alongside `local/<env>/entity_data/` so pushes stay idempotent.
- If it is missing, a push may create new entities rather than update existing ones.

## Safety

- **Read-only first.** `sync-to-local` / `stl` and `validate` do not mutate the
  Platform. Start there.
- **Dry-run before apply.** `platform push` and `sync-to-remote` / `str` are
  dry-run by default. Review the printed plan, then re-run with `--apply` only
  when the user explicitly asks to publish/deploy.
- **Confirm the env.** Double-check `--env` (e.g. `staging`) before any
  `--apply`; pushing to the wrong environment is a real mutation.
- **Never commit real data.** Do not write real customer/org names, workspace
  IDs, phone numbers, emails, addresses, or URLs into notes, commits, PRs, or
  examples. Use placeholders (`Acme Corp`, `test-org`, `user@example.com`,
  `555-010-1234`, `00000000-0000-0000-0000-000000000000`).
