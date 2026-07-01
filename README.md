# Amigo forge skills for Claude Code

Claude Code skills that let Claude drive the Amigo `forge` CLI for you - syncing agent
entities, running platform commands, and simulation testing - automatically, based on what
you ask.

## Prerequisites

1. **Claude Code** installed.
2. **The `forge` binary** on your `PATH` (see the agent-forge-go install docs). These skills
   drive the binary you already have; they don't install it.

## Install

```bash
# 1. Add this marketplace (one time)
claude plugin marketplace add amigo-ai-solutions/forge-skills

# 2. Install the forge plugin
claude plugin install forge@amigo-forge
```

## Use

In any forge project, just describe what you want - Claude picks the matching skill
automatically (e.g. "test the forge placeholder skill").
You can also invoke a skill explicitly:

```text
/forge:hello-forge
```

List installed skills with `/plugin`.

## Skills

Building an Amigo agent with the `forge` CLI, front to back:

| Skill | Use it to… |
|---|---|
| `forge-agent-design` | Scope an agent *before* building — decide where each piece of complexity belongs (a deterministic `function` vs a `context_graph` state vs an isolated `skill` vs a router vs multi-agent). Read this first. |
| `forge-build-agent` | Stand up the entities end-to-end: `persona` → `function`s → `context_graph` → `agent` → `skill`s → `service` → a pinned `version-set`. |
| `forge-validate` | Run the local, no-auth pre-push gate over your entity JSON (`forge validate`). |
| `forge-sync` | Pull, edit, validate, and push entity data between local and the Platform (`sync-to-local`/`sync-to-remote`, `platform push`). |
| `forge-simulate` | Regression-test and prove parity before promoting a `version-set`, keeping a rollback path. |

Each skill fires automatically when your request matches, or invoke one explicitly, e.g.
`/forge:forge-agent-design`.

## Updating

```bash
claude plugin marketplace update amigo-forge
```

## Optional: auto-enable inside a project

Add to your project's `.claude/settings.json` so teammates are prompted to install on trust:

```json
{
  "extraKnownMarketplaces": {
    "amigo-forge": { "source": { "source": "github", "repo": "amigo-ai-solutions/forge-skills" } }
  },
  "enabledPlugins": { "forge@amigo-forge": true }
}
```

## Troubleshooting

- Skill not firing? Confirm the plugin is enabled (`/plugin`) and you're in a forge project.
- Reinstall: `claude plugin marketplace update amigo-forge` then re-run install.
