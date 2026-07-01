---
name: forge-test
description: Smoke-test an Amigo forge CLI checkout against a live Platform API workspace. Use when the user has a forge binary or forge project with .env.platform.* configuration and asks to validate, smoke-test, or run platform commands against staging, preview, or another configured workspace before publishing or opening a PR.
---

# Forge Test

## Workflow

Run the bundled helper from the repository root:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/forge-test/scripts/forge-test.sh <environment> <workspace-name-or-id>
```

The helper builds the current checkout, runs `go test ./...`, resolves the workspace name, slug, or ID, verifies config/auth readiness, then runs one baseline live Platform API smoke command with the local binary:

- `platform workspace list --workspace <workspace-id> --env <environment> --json`

After the helper passes, inspect the PR diff and run any command-specific live checks for commands touched by the branch. Prefer read-only commands first. For mutations, use dry-run defaults when available, and only pass `--apply`, `--yes`, or other mutation-confirming flags when the user explicitly asked for that live mutation in the current turn.

## Safety Rules

- Treat `staging` as the default live test target. The helper refuses a staging profile that resolves to the production Platform API host.
- Do not test against production unless the user explicitly instructs it in the current turn. If approved, run with `FORGE_TEST_ALLOW_PROD=1`.
- Keep all JSON outputs machine-readable. On failure, report the command, exit code, and stderr/stdout summary without fabricating a success.
- Do not put real customer data in notes, commits, or PR descriptions. Refer to the workspace abstractly or by placeholder.

## Notes

- The script sets `PLATFORM_WORKSPACE_ID` only for the live smoke commands after workspace resolution, so the selected workspace is used without rewriting `.env.platform.<environment>` or the user config profile.
- If workspace lookup by name or slug is ambiguous, ask the user for the exact workspace ID rather than guessing.
