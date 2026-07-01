# Authoring forge skills

This repository publishes the public `amigo-forge` Claude Code plugin marketplace. Add new customer-facing skills conservatively and keep them tied to commands that exist in the Go `forge` binary.

## Layout

```text
forge-skills/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── forge/
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

New skills go in `plugins/forge/skills/<name>/SKILL.md`. Put helper scripts under `plugins/forge/skills/<name>/scripts/` and make executable scripts executable.

## Trigger descriptions

The `description` frontmatter is the primary quality bar. Claude invokes skills semantically, so descriptions must name observable customer context instead of internal Amigo cues.

Good descriptions include concrete triggers such as:

- A `forge` binary on `PATH`.
- A project with `.env.platform.*` files.
- A project with `local/<org>/entity_data`.
- The user asking to sync, validate, publish, simulate, test, or run platform commands.

Do not rely on repo-internal phrases, private branch names, or implementation details that customers will not say.

## Bundled scripts

Installed plugins are copied to `~/.claude/plugins/cache`, so bundled scripts must be referenced through `${CLAUDE_PLUGIN_ROOT}`:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/<helper>.sh staging test-org
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
2. Bump `version` in `plugins/forge/.claude-plugin/plugin.json`.
3. Validate the marketplace.
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
${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/...>

## Safety

<read-only first; mutations only with explicit --apply/--yes when the user asks; never write
real customer data into notes/commits/PRs>
```

## Candidate skills

Future candidates from the Python agent-forge repo include sync workflow, platform commands, and simulation/testing skills. Only port a candidate after verifying the documented command exists in `agent-forge-go` by checking its README and `forge --help` output.
