# Amigo forge skills for Claude Code and Codex

Skills that let Claude Code or Codex drive the Amigo `forge` CLI for you - designing, building,
validating, deploying, and simulation-testing Amigo agents on the Platform - automatically, based on
what you ask.

## Prerequisites

1. **Claude Code or Codex** installed.
2. **The `forge` binary** (**0.1.23 or newer**) on your `PATH` — see the agent-forge-go install
   docs, or `curl -fsSL https://forge.platform.amigo.ai/install.sh | sh`. These skills drive the
   binary you already have; they don't install it. (Model configuration needs 0.1.23+.)

## Install

### Codex

```bash
# 1. Add this marketplace (one time)
codex plugin marketplace add amigo-ai-solutions/forge-skills
```

Then open Codex, run `/plugins`, choose the **Amigo Forge** marketplace, and install the `forge`
plugin.

### Claude Code

```bash
# 1. Add this marketplace (one time)
claude plugin marketplace add amigo-ai-solutions/forge-skills

# 2. Install the forge plugin
claude plugin install forge@amigo-forge
```

## Use

In any forge project, just describe what you want - your coding agent picks the matching skill
automatically (e.g. "test the forge placeholder skill"). You can also invoke a skill explicitly:

Codex:

```text
$hello-forge
$forge-agent-design
```

Claude Code:

```text
/forge:hello-forge
```

List installed skills/plugins with `/plugins` in Codex or `/plugin` in Claude Code.

## Skills

Building an Amigo agent with the `forge` CLI, front to back:

| Skill | Use it to… |
|---|---|
| `forge-agent-design` | Scope an agent *before* building — decide where each piece of complexity belongs (a deterministic `function` vs a `context_graph` state vs an isolated `skill` vs a router vs multi-agent). Read this first. |
| `forge-build-agent` | Stand up the entities end-to-end: `function`s → `context_graph` → `agent` → `skill`s → `service` → a pinned `version-set`. |
| `forge-validate` | Run the local, no-auth pre-push gate over your entity JSON (`forge validate`). |
| `forge-sync` | Read, edit, validate, and deploy entity data via `forge platform` (`forge platform <entity> get`, then `forge platform push` — dry-run, then `--apply`). |
| `forge-simulate` | Regression-test and prove parity before promoting a `version-set`, keeping a rollback path. |

Each skill fires automatically when your request matches, or invoke one explicitly, e.g.
`$forge-agent-design` in Codex or `/forge:forge-agent-design` in Claude Code.

## Updating

### Codex

Installed plugins pick up new versions after Codex refreshes the marketplace catalog and the
installed plugin is updated. Refresh the marketplace from a shell:

```bash
codex plugin marketplace upgrade amigo-forge
```

Then open `/plugins`, update the installed `forge` plugin if prompted, and start a new thread so
Codex reloads the plugin instructions.

### Claude Code

Installed plugins only pick up new skill versions once the marketplace catalog is refreshed, the
installed plugin is updated to that version, **and** the running Claude Code session reloads its
plugins. Auto-update handles all three at startup; the manual path runs them yourself.

**Auto-update (recommended).** Auto-update is off by default for third-party marketplaces. Turn
it on so Claude Code refreshes `amigo-forge` and updates the installed `forge` plugin at startup:

- Per user, via the UI: run `/plugin` → **Marketplaces** → select `amigo-forge` → **Enable
  auto-update**.
- Org-wide, via managed settings: set `"autoUpdate": true` on the marketplace entry (see the
  snippet in [Optional: auto-enable inside a project](#optional-auto-enable-inside-a-project)).

When auto-update pulls a new version, Claude Code shows a notification prompting you to run
`/reload-plugins` — run it to activate the update in the current session.

**Manual update.** Updating is two distinct steps — refreshing the marketplace catalog does **not**
bump the installed plugin on its own:

```bash
# 1. Refresh the marketplace catalog from its source (either form works)
claude plugin marketplace update amigo-forge   # from a shell
#   /plugin marketplace update amigo-forge      # from inside Claude Code

# 2. Update the installed forge plugin to the catalog's latest version
claude plugin update forge@amigo-forge         # from a shell
#   /plugin update forge@amigo-forge            # from inside Claude Code
```

```text
# 3. Apply the update in the current Claude Code session (no restart needed)
/reload-plugins
```

`claude plugin update` on its own reports "restart required to apply"; inside a running session,
`/reload-plugins` reloads all active plugins (reporting the new skill/agent/hook counts) so the
update takes effect without restarting. Skip step 3 and the new version won't load until you
restart Claude Code.

## Optional: auto-enable inside a Claude Code project

Add to your project's `.claude/settings.json` so teammates are prompted to install on trust.
Setting `"autoUpdate": true` on the marketplace entry keeps the `forge` plugin updated at startup
without each teammate toggling it manually:

```json
{
  "extraKnownMarketplaces": {
    "amigo-forge": {
      "source": { "source": "github", "repo": "amigo-ai-solutions/forge-skills" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "forge@amigo-forge": true }
}
```

When auto-update installs a new version at startup, Claude Code prompts you to run
`/reload-plugins` to activate it in the session — see [Updating](#updating).

## Troubleshooting

- Skill not firing? Confirm the plugin is enabled (`/plugins` in Codex or `/plugin` in Claude Code)
  and you're in a forge project.
- Codex reinstall: `codex plugin marketplace upgrade amigo-forge`, then reinstall from `/plugins`.
- Claude Code reinstall: `claude plugin marketplace update amigo-forge` then re-run install.
