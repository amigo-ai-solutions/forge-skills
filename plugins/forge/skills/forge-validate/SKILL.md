---
name: forge-validate
description: Runs the local, no-auth pre-push validation gate over your Amigo entity JSON with `forge validate --entity-type <type> --env <env>` or `forge validate --all --env <env>`. Use when a forge binary is on PATH and the project has local/<env>/entity_data (or .env.platform.*), and the user asks to validate/check/lint local forge entities before a sync-to-remote or platform push, e.g. "check my forge entities", "validate my agent/context_graph/service JSON", or "is my local entity data valid before I push?".
---

# Forge Validate

`forge validate` is the local pre-push gate. It reads only the on-disk entity JSON
under `local/<env>/entity_data/<type>/*.json`, checks each file, and reports pass/fail.
It needs no authentication, calls no API, and mutates nothing. Run it on the entity
types you changed (or `--all`) before every `sync-to-remote` / `platform push`.

## When to use

- "Validate my forge entities" / "check my forge entities" / "lint my local entity data."
- "Is my agent / context_graph / service JSON valid before I push?"
- Right after editing files under `local/<env>/entity_data/...` and before you push.
- A `forge` binary is on `PATH` and the project has `local/<env>/entity_data` (or `.env.platform.*`).

### When NOT to use -> use a sibling instead

- To fix *what* an agent should do or how it is scoped (design decisions, altitude,
  boundaries) -> use `/forge-agent-design`.
- To author or edit the entity files themselves -> use `/forge-build-agent`.
- To push local entities to remote once validation passes -> use `/forge-sync`.
- To run scenario simulations or regression sims against a live service -> use `/forge-simulate`.

Validate is the checkpoint *between* authoring/building and syncing: author with
`/forge-build-agent`, validate here, then push with `/forge-sync`.

## Valid entity types

Use one of these for `--entity-type` (or `--all` to validate every type):

```
agent            context_graph        dynamic_behavior_set   metric
persona          scenario             service                tool
unit_test_set    unit_test            user_dimension
```

## Workflow

1. Confirm the binary and the local layout exist.

   ```bash
   forge --help
   ls local/staging/entity_data
   ```

   Entity files live at `local/<env>/entity_data/<type>/*.json`. Use the env whose
   data you edited (examples below use `staging`; substitute your `--env <env>`).

2. Validate the entity types you changed. On `validate`, `-e` means `--entity-type`,
   so always spell out `--env` in full.

   ```bash
   forge validate --entity-type agent --env staging
   forge validate --entity-type context_graph --env staging
   forge validate --entity-type service --env staging
   ```

3. Or validate everything at once before a full push.

   ```bash
   forge validate --all --env staging
   ```

4. Read the output.
   - Success ends with `validation complete: all entities passed validation`.
   - Per-type sections print as `-- Validating <type> --`.
   - `no local entities found in local/<env>/entity_data/<type>` means there is
     nothing on disk for that type under that env. If you expected files there,
     check the `--env` value and the directory path before re-running.
   - A failure names the offending file and the reason (for example a malformed
     JSON body or a missing/invalid required field).

5. Fix and re-run until clean.
   - Correct the reported file (edit it directly, or re-author it with
     `/forge-build-agent`; for scoping/design problems use `/forge-agent-design`).
   - Re-run the same `forge validate` command until you get
     `all entities passed validation`.

6. Only after validation passes, hand off to `/forge-sync` to push local -> remote.

## Safety

- `forge validate` is read-only and local-only: no auth, no network, no writes.
  It is always safe to run and to re-run.
- It is a gate, not a fix: it never edits your entity files. Make edits yourself
  (or via `/forge-build-agent`) and re-validate.
- Treat a passing validate as the precondition for `/forge-sync` and `platform push`,
  not a substitute for them. Those mutating pushes are dry-run by default and only
  apply changes with an explicit `--apply` when the user asks.
- Use only synthetic placeholder data in examples and notes (org `Acme Corp`,
  workspace `test-org`, `user@example.com`, `555-010-1234`,
  UUID `00000000-0000-0000-0000-000000000000`). Never write real customer data into
  notes, commits, or PRs.
