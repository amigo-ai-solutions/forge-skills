# Authoring forge skills

This repository publishes the public `amigo-forge` skill marketplace for Claude Code and Codex. Add new customer-facing skills conservatively and keep them tied to commands that exist in the **released** Go `forge` binary — verify against the release artifact (currently ≥ 0.1.23), not a local source build, which can be ahead of what customers run.

## Layout

```text
forge-skills/
├── .agents/
│   └── plugins/
│       └── marketplace.json
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── forge/
│       ├── .codex-plugin/
│       │   └── plugin.json
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── skills/
│           └── hello-forge/
│               └── SKILL.md
├── templates/
│   └── SKILL.md.example
├── README.md
├── AUTHORING.md
└── LICENSE
```

New skills go in `plugins/forge/skills/<name>/SKILL.md`. Put helper scripts under `plugins/forge/skills/<name>/scripts/` and make executable scripts executable. Keep `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` at the same version whenever a released skill changes.

## Command surface (hard rules)

- **Document only `forge platform ...` commands.** `forge validate` (local, no API) and `forge auth ... --platform` are also allowed. Do **not** document the classic backend commands `sync-to-local` / `sync-to-remote` (aliases `stl` / `str`) or the legacy `.env.<env>` surface — the Platform surface uses `.env.platform.<env>`.
- **Verify against the released binary.** Run every command against the release artifact (`curl -fsSL https://forge.platform.amigo.ai/install.sh | sh`, currently ≥ 0.1.23) before documenting it. Model configuration (`forge platform version-set upsert --body`) requires ≥ 0.1.23.
- **No `persona`.** The standalone persona entity is retired; author identity in the agent's own instructions and never reference a `persona` entity (or the word).
- **Version-sets:** `release` is the live set; pin a writable named set (e.g. `candidate`) to test; `edge` is a reserved name that may not exist — don't target it.

## Trigger descriptions

The `description` frontmatter is the primary quality bar. Claude Code and Codex invoke skills semantically, so descriptions must name observable customer context instead of internal Amigo cues.

Good descriptions include concrete triggers such as:

- A `forge` binary on `PATH`.
- A project with `.env.platform.*` files.
- A project with `local/<org>/entity_data`.
- The user asking to sync, validate, publish, simulate, test, or run platform commands.

Do not rely on repo-internal phrases, private branch names, or implementation details that customers will not say.

## Bundled references and scripts

Prefer relative references from the skill directory for bundled files:

```text
reference/<file>.md
scripts/<helper>.sh
```

When a shell command truly needs the installed plugin root, write it so both plugin surfaces work:

```bash
"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/<name>/scripts/<helper>.sh" staging test-org
```

Do not use repo-relative paths such as `.codex/skills/...` or `plugins/forge/skills/...` inside skill workflows.

## Customer safety

Do not write real customer or organization names, workspace IDs, phone numbers, emails, addresses, or URLs into skills, notes, commits, PRs, examples, or fixtures.

Use these placeholders:

- Organization: `Acme Corp`
- Slug or workspace name: `test-org`
- Email: `user@example.com`
- Phone: `555-010-1234`
- UUID: `00000000-0000-0000-0000-000000000000`

## Release process

1. Add or update skills.
2. Bump `version` in both plugin manifests:
   - `plugins/forge/.codex-plugin/plugin.json`
   - `plugins/forge/.claude-plugin/plugin.json`
3. Validate both plugin surfaces.
4. Commit and open a PR.
5. After merge, tag the release as `vX.Y.Z`.

Customers only receive plugin updates when the `version` string changes.

## Validation

Every contributor must pass this before committing:

```bash
claude plugin validate .
```

Fix JSON syntax, duplicate skill names, missing frontmatter, and invalid path references before opening a PR.

## Skill template

```markdown
---
name: forge-<verb>
description: <One-two sentences. Start with what it does, then "Use when ..." listing concrete customer triggers - a forge binary on PATH, a project with .env.platform.* or local/<org>/entity_data, or the user asking to <sync/validate/publish/simulate/run platform commands>.>
---

# Forge <Verb>

## When this applies

<observable preconditions>

## Workflow

<numbered steps that invoke `forge ...` commands; reference bundled scripts as
scripts/<helper>.sh or "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/skills/<name>/scripts/...">

## Safety

<read-only first; mutations only with explicit --apply/--yes when the user asks; never write
real customer data into notes/commits/PRs>
```

## Shipped skills

The marketplace currently ships `forge-agent-design` (scoping/placement), `forge-build-agent` (build entities end-to-end), `forge-validate` (local gate), `forge-sync` (read/deploy via `forge platform`), and `forge-simulate` (regression + parity gate), plus the `hello-forge` placeholder. Before adding another: keep it `forge platform`-only (see Command surface), verify every documented command against the released binary, and add a row to the Skills table in `README.md`.
