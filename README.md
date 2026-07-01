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
claude plugin marketplace add amigo-ai/forge-skills

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

## Updating

```bash
claude plugin marketplace update amigo-forge
```

## Optional: auto-enable inside a project

Add to your project's `.claude/settings.json` so teammates are prompted to install on trust:

```json
{
  "extraKnownMarketplaces": {
    "amigo-forge": { "source": { "source": "github", "repo": "amigo-ai/forge-skills" } }
  },
  "enabledPlugins": { "forge@amigo-forge": true }
}
```

## Troubleshooting

- Skill not firing? Confirm the plugin is enabled (`/plugin`) and you're in a forge project.
- Reinstall: `claude plugin marketplace update amigo-forge` then re-run install.
