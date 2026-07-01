---
name: forge-agent-design
description: Design/scoping guide for Amigo agents — decides WHERE each piece of complexity belongs (deterministic function vs context-graph state vs isolated skill vs router vs multi-agent) before you build, and maps each choice onto a concrete forge entity/command. Use when scoping or structuring an Amigo agent; deciding function vs skill vs context-graph state; whether to route a concern out to an isolated sub-agent/skill; when a prompt or context-graph state has too many or conflicting instructions; asking "where should this complexity live"; or before running forge platform push/simulate to build/validate/deploy. Read this FIRST when scoping, then hand off to forge-build-agent, forge-validate, forge-sync, or forge-simulate.
---

# Forge Agent Design — Where Should the Complexity Live?

A field guide for scoping an Amigo agent *before* you build: decide where each piece of
complexity belongs, then place it in the forge entity that implements it. This is the
read-first skill when scoping — it reasons about structure and then hands off to the
command-running skills.

## When to use

Reach for this skill when the task sounds like:

- "Help me scope / structure this agent."
- "Should this be a function, a skill, or a context-graph state?"
- "Should I route this concern out to a separate sub-agent/skill?"
- "This prompt (or context-graph state) has too many / conflicting instructions."
- "Where should this complexity live?"
- "Do I need multiple agents here?"

### When NOT to use — route instead

- Ready to author entity JSON and push it -> use **/forge-build-agent**.
- Just checking local files pass validation -> use **/forge-validate**.
- Pulling remote entities down / pushing local up -> use **/forge-sync**.
- Running regression or interactive simulations to prove behavior -> use **/forge-simulate**.

This skill decides *what to build and where*; the others build, validate, sync, and test it.

## The one rule

**Non-determinism is a budget.** An LLM step is the least predictable, most expensive,
hardest-to-test way to do a job — so spend it only where the problem is genuinely
irreducible. Add agentic complexity **only when it demonstrably improves outcomes**;
otherwise use the simplest thing that works (Anthropic). Default to **one agent**, and
split only on real signals (OpenAI).

## The placement cascade — prefer the earliest rung that works

Prefer the earliest (lowest-cost) rung that holds. Move work **down** the table as
patterns stabilize; reach **up** only when the rung below provably can't hold it.

| Rung | Use when | Cost / risk | Forge entity |
|---|---|---|---|
| **Deterministic code / data lookup** | the rule is known and stable | lowest — fast, cheap, testable | a `function` (`forge platform function register` / `test` / `query`), or precomputed data a tool reads — costs zero of the agent's instruction budget |
| **Workflow** (LLM steps on a predefined path) | task is well-defined and decomposable | low — predictable | `context_graph` states arranged on a fixed path |
| **Single agent + tools** | the path is open-ended; the model must decide mid-task | medium | an `agent` + its `tool`s (wire-check with `forge platform tool-test resolve` / `execute`), default to a single-state context graph |
| **Isolated sub-agent / skill** (clean interface) | one bounded concern is high-stakes or must-be-exact | medium — but testable in isolation | a `skill` (`forge platform skill create` / `test` / `references`); a light top-level context-graph routes to it |
| **Router -> orchestrated skills** | several distinct, bounded modes | higher | a context-graph decision-style state routing to several `skill`s |
| **Multi-agent** | genuinely parallel, separable work | highest — coordination + drift | multiple agents/services; only for parallel, read-only work — keep writes single-threaded |

The agent's **identity/voice** carries most behavior — author it in the `agent`'s own
global instructions (reinforced by the `context_graph`), not as scattered per-state rules.

For the full rung table, a symptom -> forge-entity lookup, and worked examples, see
`${CLAUDE_PLUGIN_ROOT}/skills/forge-agent-design/reference/placement-cascade.md`.

## Workflow or agent? (Anthropic)

- **Workflow** = LLMs + tools on **predefined code paths** -> predictable, consistent;
  best for well-defined tasks. In forge, that is a `context_graph` with states on a fixed
  path (prompt-chaining, routing, parallelization, orchestrator-workers,
  evaluator-optimizer).
- **Agent** = the model **directs its own process and tool use** -> flexible; best when
  the trajectory can't be scripted. In forge, that is an `agent` with `tool`s, defaulting
  to a single-state context graph.
- The discipline: add complexity only when it improves outcomes, keep tools/interfaces
  simple, and design from the agent's point of view.

## Start with one agent; split only on real signals (OpenAI)

Maximize a **single agent** (one model + tools in a loop) first — more agents add
coordination overhead. **Split when** the prompt is a thicket of **conditionals** that
won't scale, or there's **tool overload** / the agent keeps **selecting the wrong tool**.

- Distinct modes -> split into `context_graph` states.
- A recurring bounded sub-judgment -> pull it out into a `skill`.
- Prefer a **manager** pattern (sub-agents/skills exposed as tools, routed by a
  context-graph state) over free-form handoffs.

## Route must-be-exact behavior OUT

When something must fire with **no deviation** (a legal answer, a clinical/safety
escalation, a dosing rule): a **light top-level** context-graph state **routes** that case
to a **fast, isolated** `skill` that composes the exact response.

- **Recognition stays on the strong model** — never downgrade the safety recognizer;
  the isolated skill only *generates* the exact response.
- **Prove parity** on a **binary, per-category eval** *before* removing the old path.
  In forge, prove parity with simulations (`forge platform sim bridge` for coverage,
  `forge platform simulation session step` for controlled turns) and score the runs.
- **Keep the old path live as fallback** until proven, then **cut over per surface** with
  `forge platform version-set promote`, keeping `forge platform version-set rollback`
  ready.
- **Smell test:** a pile of competing "HIGHEST PRIORITY" rules in one prompt/state is the
  anti-pattern. Measure *instruction* text, not data payload; **contradiction**, not
  length, is the signal to split.

## Own your context; keep writes single-threaded (12-Factor + Cognition)

- **Agents are mostly software** with LLM steps at the right points. Own your prompts and
  your context window; a tool is just **structured output that triggers deterministic
  code** — in forge, that deterministic code is a `function`.
- **Context engineering is the #1 job:** share **full** context (complete traces, not
  snippets). For anything multi-step, keep **writes single-threaded** — extra agents
  should **contribute intelligence, not take conflicting actions**; exactly one writer
  commits.

## Push down the determinism gradient (the scaling move)

The agent is a **discovery vehicle, not a production target.** Learn the pattern in messy
orchestration, then distill the stable parts down the cascade: agent reasoning ->
orchestrated `skill` -> **materialized `function`/data lookup**. A chain of twenty tool
calls that has stabilized should become **one `function`** — cheaper, faster, observable,
deterministic.

## Decision checklist (each item points at the forge move)

- [ ] Could a deterministic **lookup or workflow** do this? -> a `function`
  (`forge platform function register`) or fixed-path `context_graph` states. If yes, stop
  there.
- [ ] **One agent + tools** first — is there a *real* reason to split (conditional thicket
  / tool overload)? Wire-check tools with `forge platform tool-test resolve` before
  adding more.
- [ ] Any **must-be-exact / high-stakes** behavior? -> isolate it into a testable `skill`
  (`forge platform skill create` / `test`); recognition stays on the strong model;
  parity-gated cutover; fallback retained.
- [ ] Is the agent's identity/voice scattered across instructions? -> consolidate it into
  the `agent`'s own global instructions, not per-state rules.
- [ ] **Writes single-threaded?** Context shared in full? Keep exactly one writer.
- [ ] What is the **eval/parity gate** and the **rollback**? -> prove parity with
  simulations, deploy via a `service` + `version-set`, cut over with
  `forge platform version-set promote`, keep `forge platform version-set rollback`.
- [ ] Which stable parts can be **pushed down to a `function`/data** now (or soon)?

## Safety

- This is a **read-only, design-time** skill: it reasons and points at commands; it does
  not mutate anything on its own.
- When you hand off to build/validate/sync/simulate, stay **read-only first**
  (`forge platform ... list` / `get`, `forge platform tool-test resolve`,
  `forge validate`); run mutations only with an explicit `--apply` / `--yes` and only when
  the user asks. `forge platform push`, `forge sync-to-remote`, and mutating `version-set`
  commands are **dry-run by default** — keep them that way until the user confirms.
- Use **synthetic data only** in simulations (placeholder org `Acme Corp`, phone
  `555-010-1234`, UUID `00000000-0000-0000-0000-000000000000`). Never write real customer
  data into notes, commits, or PRs.

## Sources

- Anthropic — *Building Effective Agents* — <https://www.anthropic.com/research/building-effective-agents>
- OpenAI — *A Practical Guide to Building Agents* (PDF) — <https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf>
- HumanLayer — *12-Factor Agents* — <https://github.com/humanlayer/12-factor-agents>
- Cognition / Walden Yan — *Don't Build Multi-Agents* — <https://cognition.com/blog/dont-build-multi-agents> · follow-up *Multi-Agents: What's Actually Working* — <https://cognition.com/blog/multi-agents-working>
