# CLAUDE.md - forge-skills

This repo publishes the **public `amigo-forge` skill marketplace for Claude Code and Codex**:
skills that let coding agents drive the Amigo **`forge` CLI** to design, build, validate, deploy,
and simulation-test agents on the Amigo Platform. It does **not** contain the `forge` binary - the
skills drive the binary the user already installed (from `agent-forge-go`).

## Layout

- `.agents/plugins/marketplace.json` - Codex marketplace manifest
- `.claude-plugin/marketplace.json` - Claude Code marketplace manifest
- `plugins/forge/.codex-plugin/plugin.json` - Codex plugin manifest (**bump `version` on every skill change**)
- `plugins/forge/.claude-plugin/plugin.json` - Claude Code plugin manifest (**bump `version` on every skill change**)
- `plugins/forge/skills/<name>/SKILL.md` - one skill per directory (+ optional `reference/*.md`, `scripts/*`)
- `AUTHORING.md` - full authoring guide (read before adding/editing skills)
- `templates/SKILL.md.example` - skill template

## Skills (current set)

- `forge-agent-design` — scope where complexity belongs before building (+ `reference/placement-cascade.md`)
- `forge-build-agent` — build the entities end-to-end (+ `reference/skill-prompting.md`, `reference/agent-context-graph-authoring.md`)
- `forge-validate` — local, no-auth pre-push validation gate
- `forge-sync` — read/edit/validate/deploy the entity JSON via `forge platform ...`
- `forge-simulate` — regression sims + parity gate + rollback
- `hello-forge` — placeholder

## Hard rules

1. **Document only `forge platform ...` commands.** `forge validate` (local, no API) and
   `forge auth ... --platform` are also allowed. Do **not** document the classic backend
   commands `sync-to-local` / `sync-to-remote` (aliases `stl` / `str`) or the legacy
   `.env.<env>` surface - the Platform uses `.env.platform.<env>`.
2. **Verify every command against the RELEASED `forge` binary, not a source build.** A source
   build can be ahead of what customers run. Current release is **≥ 0.1.23**; model
   configuration (`version-set upsert --body`) requires it. Grab the release
   (`curl -fsSL https://forge.platform.amigo.ai/install.sh | sh`) and run each command first.
3. **No `persona`.** The standalone persona entity is retired - author identity in the agent's
   own instructions; never reference a `persona` entity (or the word).
4. **Version-sets:** `release` is the live set; pin a writable named set (e.g. `candidate`) to
   test; `edge` is a reserved name that may not exist — don't target it.
5. **Model config:** three providers (OpenAI / Anthropic / Google Gemini), set on a version-set
   via `llm_model_preferences` through `forge platform version-set upsert --body/--file`. Keep
   model IDs family-level; the skill default is `claude-sonnet-4-6`.
6. **Customer-safe:** placeholders only - `Acme Corp` / `Example Health`, `test-org`,
   `user@example.com`, `555-010-1234`, `00000000-0000-0000-0000-000000000000`. No customer or
   internal data, no Notion/internal URLs, no `poetry run` (Python V1).

## Ship a change

1. Edit skills / docs.
2. If skills changed, bump both `plugins/forge/.codex-plugin/plugin.json` and
   `plugins/forge/.claude-plugin/plugin.json` `version` values (customers only get updates when it
   changes).
3. Run `claude plugin validate .`.
4. Run the Codex plugin validator when available.
5. Open a PR to `main` - the repo **blocks merge commits, so squash-merge**.
6. Tag `vX.Y.Z` after merge only when cutting a release.

See `AUTHORING.md` for the full authoring guide and `agent-forge-go`'s `USAGE.md` for the CLI.
