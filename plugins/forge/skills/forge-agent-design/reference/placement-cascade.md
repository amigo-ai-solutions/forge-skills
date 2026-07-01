# Placement Cascade — Full Reference (forge)

Companion to the `forge-agent-design` skill. Use this when you need the full rung table,
a symptom -> forge-entity lookup, or worked examples. The skill body has the summary; this
file is the deep reference.

Every `forge ...` command below is a real `agent-forge-go` command. Design-time reasoning
is read-only; mutations (`forge platform push`, `forge sync-to-remote`, mutating
`version-set`) are dry-run by default and only go real with `--apply`.

---

## The rule

**Non-determinism is a budget.** The LLM step is the most expensive, least testable rung.
Spend it only where the problem is genuinely irreducible. Prefer the earliest (lowest)
rung that works; move work **down** as patterns stabilize; reach **up** only when the rung
below provably can't hold it.

---

## Full rung -> forge-entity table

| Rung | Use when | Cost / risk | Forge entity | Key commands (read-only unless noted) |
|---|---|---|---|---|
| **Deterministic code / data lookup** | the rule is known and stable; no judgment needed | lowest — fast, cheap, deterministic, fully testable | a `function` (or precomputed data a tool reads); costs **zero** of the agent's instruction budget | `forge platform function catalog` · `forge platform function register --name/-n <name> --type/-t <type> [--input-schema/-i <file.json>]` · `forge platform function test <name> --input/-i '{...}'` · `forge platform function query --sql/-s "SELECT ..."` |
| **Workflow** (LLM steps on a predefined path) | task is well-defined and decomposable into fixed steps | low — predictable, consistent | `context_graph` states arranged on a **fixed path** | edit `local/<env>/entity_data/context_graph/*.json`; `forge validate --entity-type context_graph --env <env>`; `forge platform context-graph get <id>` |
| **Single agent + tools** | the path is open-ended; the model must decide mid-task | medium | an `agent` + its `tool`s; default to a **single-state** context graph | `forge platform agent get <id>` · `forge platform tool-test resolve --service-id <id>` · `forge platform tool-test execute --service-id <id> --tool-name <name> --dry-run` |
| **Isolated sub-agent / skill** (clean interface) | one bounded concern is high-stakes or must-be-exact | medium — but **testable in isolation** | a `skill`; a light top-level context-graph state routes to it | `forge platform skill list` · `forge platform skill get <id>` · `forge platform skill create --file/-f skill.json` · `forge platform skill test <id> --file/-f case.json` · `forge platform skill references <id>` |
| **Router -> orchestrated skills** | several distinct, bounded modes | higher | a context-graph **decision-style** state routing to several `skill`s | edit the routing `context_graph` state; `forge validate --entity-type context_graph --env <env>` |
| **Multi-agent** | genuinely **parallel, separable, read-only** work | highest — coordination + drift | multiple `agent`s / `service`s; keep **writes single-threaded** | `forge platform service list` · design so exactly one writer commits |

**Identity/voice** carries most behavior — author it in the `agent`'s own global
instructions (reinforced by the `context_graph`), not as scattered per-state rules.

**Deploy + eval/parity gate + rollback** (any rung): deploy via a `service` + a
`version-set`, prove parity with simulations, cut over per surface, keep rollback ready.

Version-set vocabulary:

- **`edge`** — a built-in set that auto-tracks the *latest* pushed agent/context-graph
  versions. Always present once the service has versions; **immutable** — you cannot
  `upsert` it or `promote` into it, but you can simulate against it and `promote` *from* it.
- **`release`** — the live/production set; a writable `promote` / `upsert` target.
- a **named set** (e.g. `candidate`) — a writable set you pin to exact versions with
  `upsert`, then `promote` into `release`.

```bash
# stage a writable candidate set at exact versions (dry-run; add --apply to commit)
forge platform version-set upsert <service-id> candidate --agent-version 3 --context-graph-version 5
forge platform version-set diff <service-id> release candidate
# prove parity before cutover (see "Prove parity" below), then:
forge platform version-set promote <service-id> candidate release --apply   # cut over
forge platform version-set rollback <service-id> --apply                     # rollback path
```

---

## Symptom -> where it belongs (which forge entity)

| Symptom you observe | Where it belongs | Forge move |
|---|---|---|
| Prompt/state explains **how to compute, de-dupe, or reconcile** data | Deterministic lookup | push it into a `function`; `forge platform function register` then `forge platform function test <name>` |
| A **chain of ~20 tool calls** that has stabilized into one predictable path | Deterministic lookup | collapse into **one** `function` (materialize the lookup) |
| Steps always run in the **same fixed order** | Workflow | `context_graph` states on a fixed path |
| The model must **choose its own next step** mid-task | Single agent + tools | keep it one `agent` + `tool`s; wire-check with `forge platform tool-test resolve` |
| One prompt **mixing several distinct modes** (e.g. FAQ + triage + billing) | Router -> modes | make each mode a `context_graph` state; route with a decision state |
| A **recurring sub-judgment** repeated across states | Isolated skill | pull it into a `skill` (`forge platform skill create`), route to it |
| A **legal/safety/clinical** answer that must **never deviate** | Isolated skill (testable to 100%) | route to an isolated `skill`; recognition stays on the strong model; `forge platform skill test` to full coverage |
| A pile of competing **"HIGHEST PRIORITY"** rules in one prompt/state | Split on **contradiction** | separate the contradicting concerns into distinct states/skills — length is not the signal, contradiction is |
| Agent keeps **selecting the wrong tool** / tool overload | Split | fewer tools per agent; route modes via `context_graph` states |
| Voice/identity/tone **scattered** across instructions | The agent | author identity in the `agent`'s own global instructions, reinforced by the `context_graph` |
| Two agents that could **both write** the same state | Keep writes single-threaded | exactly one writer commits; others contribute intelligence only |

---

## Prove parity before cutover

Before removing an old path, prove the new one matches on a binary, per-category basis.
Use **synthetic** data only.

```bash
# broad regression coverage against a service (many generated scenarios)
forge platform sim bridge --service-id <service-id> \
  --objective "Caller asks about a bill; agent must escalate safety concerns verbatim" \
  --num-scenarios 20

# controlled, turn-by-turn check of the exact must-be-exact path
forge platform simulation run create --service-id <service-id>
forge platform simulation session create --run-id <run-id> --service-id <service-id> \
  --caller-id 555-010-1234 --entity-id 00000000-0000-0000-0000-000000000000
forge platform simulation session step  --session-id <session-id> --text "I'm having chest pain"
forge platform simulation session score --session-id <session-id> --score 1 --rationale "exact escalation fired"

# inspect a session's behavior/intelligence when a run looks off
forge platform sim session-observe      <session-id>
forge platform sim session-intelligence <session-id>
```

Only after parity holds do you `forge platform version-set promote <service-id> edge release --apply`
(keeping `forge platform version-set rollback <service-id> --apply` as the fallback).

---

## Worked examples (sanitized; rephrased into forge terms)

### 1. Prompt explaining how to de-dupe / reconcile data -> a function

**Symptom.** An `Acme Corp` support agent's prompt contains a long block explaining how to
merge duplicate account records and pick the canonical one — deterministic rules the model
re-derives every turn, burning instruction budget and drifting.

**Placement.** Deterministic lookup. The reconciliation rule is known and stable, so it is
the **lowest** rung.

**Forge move.**

```bash
forge platform function register --name reconcile_account --type python \
  --description "Return the canonical account for a set of duplicate ids" \
  --input-schema '{"type":"object","properties":{"ids":{"type":"array"}}}'
forge platform function test reconcile_account --input '{"ids":["a","b"]}'
```

The agent now calls one tool that triggers deterministic code; the reconciliation
instructions leave the prompt entirely.

### 2. One prompt mixing FAQ + triage + billing -> context-graph states + skills

**Symptom.** An `Example Health` line-1 agent has a single prompt that answers FAQs,
triages symptoms, and handles billing — three distinct modes with competing rules.

**Placement.** Router -> modes. The distinct modes become **`context_graph` states**; a
recurring sub-judgment (e.g. "is this a billing dispute vs. a payment question") becomes a
**`skill`** the states route to.

**Forge move.** Split the one state into `faq`, `triage`, and `billing` states in
`local/<env>/entity_data/context_graph/*.json`, add a decision state that routes to them,
and extract the recurring judgment into a skill:

```bash
forge platform skill create --file classify_billing_intent.json
forge validate --entity-type context_graph --env staging
```

Start with one agent; split **only** because of the conditional thicket, not length.

### 3. A legal/safety answer that must never deviate -> an isolated skill tested to 100%

**Symptom.** An `Example Health` agent must give an **exact** safety escalation when a
caller reports specific symptoms — no paraphrase, no deviation.

**Placement.** Isolated sub-agent / skill. Route the recognized case **out** to a
fast, isolated `skill` that composes the exact response.

**Forge move.**

```bash
forge platform skill create --file safety_escalation.json
# test to full coverage on the binary "did the exact escalation fire?" eval
forge platform skill test <skill-id> --file escalation_cases.json
```

- **Recognition stays on the strong model** — the top-level context-graph state recognizes
  the case; the isolated skill only generates the exact wording.
- **Prove parity** (see above) on a binary, per-category eval *before* removing the old
  path; keep the old path live as **fallback**.
- **Cut over per surface** with `forge platform version-set promote <service-id> edge release --apply`;
  keep `forge platform version-set rollback <service-id> --apply` ready.

---

## Sources

- Anthropic — *Building Effective Agents* — <https://www.anthropic.com/research/building-effective-agents>
- OpenAI — *A Practical Guide to Building Agents* (PDF) — <https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf>
- HumanLayer — *12-Factor Agents* — <https://github.com/humanlayer/12-factor-agents>
- Cognition / Walden Yan — *Don't Build Multi-Agents* — <https://cognition.com/blog/dont-build-multi-agents> · follow-up *Multi-Agents: What's Actually Working* — <https://cognition.com/blog/multi-agents-working>
