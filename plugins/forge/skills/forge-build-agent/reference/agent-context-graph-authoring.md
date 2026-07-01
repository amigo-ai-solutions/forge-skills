# Authoring forge agents and context graphs

Public authoring guidance for the forge `agent` and `context_graph` entities. Companion to
`/forge-build-agent` (the build workflow) and `/forge-agent-design` (where each piece of
complexity belongs). Read `/forge-agent-design` first to decide placement; this file is how
to author the two entities well once the shape is settled.

The mental model: an **`agent`** is a strong identity/voice plus tools; a **`context_graph`**
is the structured problem space it traverses; a **`skill`** is a single Anthropic-model
system prompt that uses tools; a **`function`** is deterministic code. Author each with the
forge CLI, then `forge validate` before pushing.

---

## Part 1 — Authoring the agent

### Identity carries most of the behavior

A well-built agent should handle roughly **70-80% of its behavioral decisions from identity
and voice alone** — who it is, what it knows, what it believes, how it talks. The remaining
~20-30% (specific flows, edge cases, domain requirements) is structure supplied by the
`context_graph` and routed-out `skill`s.

- Author identity/voice in the **agent's own global instructions** (in the agent definition
  and its versions via `forge platform agent create` / `create-version`), reinforced by the
  `context_graph`. Identity is not a separate entity.
- **Diagnostic:** if you are stacking action rules or boundary constraints to compensate for a
  thin identity, invest in characterization instead of piling rules onto the graph.
- **Why it matters for edge cases:** with a rich, coherent identity, off-happy-path moments
  are handled *axiomatically* — they feel like something this agent would naturally do. A thin
  identity makes the same moments feel random and off-script.

Build the agent like a portrait at increasing resolution: identity as the foundational
sketch, background/expertise/philosophy as depth, then behaviors and voice as fine-tuning.

### A clear objective, separate from identity

Give the agent (and each `context_graph` state) a **single clear objective** — the goal to
achieve before moving on. Keep it distinct from identity: identity is *who the agent is and
how it acts*; the objective is *what this interaction is trying to accomplish*. Progress
toward the objective is the **lowest-priority** driver — a coherent identity and its guidelines
take precedence over rushing to the goal. Pursue the objective *through* that identity.

### Two kinds of instruction — keep them separate

| Kind | What it governs | Nature | Home in forge |
|---|---|---|---|
| **Action / navigation guidelines** | *How* to do the work: tone, strategy, moving through steps, when to advance | Interpreted flexibly in context | agent global instructions; per-step versions attach to a `context_graph` state |
| **Boundary constraints** | Hard "NEVER" rules: safety, scope-of-practice, things it must not say or do | Non-negotiable | agent globals; state-level for state-specific limits; must-be-exact behavior routed **out** to a `skill` |

### Minimal viable constraint (start rich, then reduce)

Non-determinism is a budget, and every instruction competes for the model's attention — add
the **fewest constraints that reliably produce the behavior**.

- Build **reductively, not additively**: start from a strong, tested superset of guidelines
  and delete what is almost certainly irrelevant, rather than writing from scratch. Keep
  uncertain ones on the first pass (deleting later is easier than diagnosing a missing
  behavior), customize wording to this agent's voice, then add genuinely novel constraints.
- Experts in a role are largely alike; the difference is a thin slice of nuance. A strong
  agent for one role is a reusable template — get the shared core right, then customize the
  differentiating slice. Iterate with `create-version` rather than rebuilding.

### Instruction hygiene

- Keep instructions **few, coherent, and non-contradictory**. The failure signal is a pile of
  competing "HIGHEST PRIORITY" rules crowded into one prompt or one state.
- **Measure the *instruction* text, not the data payload.** A long prompt full of retrieved
  data is fine; a short prompt whose rules fight each other is not. **Contradiction, not
  length, is the signal to split.**
- **State a clear priority order** so conflicts resolve deterministically: hard boundary
  constraints and the active state's action guidelines first, then identity/behavior, then
  voice/communication style, then progress toward the objective.
- **One idea at a time in output** — favor a single concept per response and avoid stacked
  questions.

### Structure the identity as background elements

Author the agent's identity as a background with these elements (the first four are required):

- **Motivations** *(required)* — the driving forces behind how the agent acts.
- **Biography** *(required)* — a coherent backstory that grounds its expertise and voice.
- **Expertise** *(required)* — the specific knowledge and skills it brings.
- **Philosophy** *(required)* — the beliefs and principles that shape its approach.
- **Achievements**, **Relationships**, **Evolution**, **Current Status**, **Vision** *(optional)* — added depth that makes edge-case behavior feel consistent.

Write them in the agent's own voice; a rich, coherent identity handles off-happy-path moments
axiomatically. Sanitized sketch:

```md
# Motivations
- I want every caller to leave more capable than they arrived — a problem fully resolved on
  first contact, not a ticket passed along.
# Biography
- Years on the Acme Corp support floor; grew from frontline agent to a senior specialist who
  trains new hires on de-escalation.
# Expertise
- Deep knowledge of Acme Corp's order, billing, and subscription systems and their edge cases.
# Philosophy
- A caller who feels heard forgives almost anything; confirm you understand the problem before
  proposing a fix.
```

### Behavior vs. communication guidelines

Split identity-level guidelines by *where they apply*:

- **Behavior** = the *what*, relevant to both the agent's reasoning **and** its replies
  (e.g. "resolve the caller's stated problem before introducing anything new").
- **Communication** = the *how*, relevant only to the reply
  (e.g. "acknowledge briefly, then answer in one or two sentences").

A behavior shapes decisions even when the agent is silent; a communication rule only shapes wording.

### Few-shot examples in guidelines: templates, not transcripts

When a guideline needs examples, prefer **generalizable templates with `[placeholders]`** over
fixed verbatim lines — a hardcoded example gets parroted; a template transfers. To push
open-ended questions, for instance:

> Favor open questions using shapes like *"What is your `[goal]` right now?"*,
> *"What `[aspect]` stands out to you?"*, *"What's behind `[concern]` for you?"* — not one fixed
> script, and avoid yes/no ("Are/Is …") phrasings.

The same rule governs a `skill`'s prompt (see `skill-prompting.md`): show the *shape* of a good
turn and cover an edge case, rather than one exact wording the model will over-copy.

---

## Part 2 — Authoring the context graph

A `context_graph` is a set of **states** and the **transitions** between them. It is
deliberately *incomplete* — a working experience only when composed with the `agent` and its
tools/skills. Add just enough structure to guarantee quality outcomes, and no more. Start with
a **single-state graph** and add states only when a real signal forces it.

### What a state is — and when to add one

A state is **one coherent conversational mode**: one narrow purpose, one completion contract,
one self-consistent instruction set. The test: *"This state exists to ___ and is complete when
___."* If you can't fill both blanks in one sentence, it is doing too much or isn't a real
state.

**Add a distinct state only when there is a genuinely distinct conversational mode** — how the
agent talks, what it is trying to accomplish, and what "done" means all shift. Signals:

- The objective changes (gathering intake vs. proposing an approach vs. closing out).
- The exit criteria change.
- The instruction set would contradict itself if merged with the neighbor.

**Do NOT add a state for:**

- **A computation or lookup** — put it in a `function` (deterministic, cheap, testable, zero
  instruction budget) or precomputed data a tool reads.
- **A single bounded skill** — a must-be-exact / high-stakes response belongs in an isolated
  `skill`; the graph *routes* to it, not inlines it.
- **Convenience/organization** — naming or phase grouping is not a reason to fragment.

**Anti-patterns:** one mega-state that greets, assesses, routes, reflects, and schedules
(split it); a state for a trivial 1-2 message step the neighbor already covers (merge it).

### Context density — minimal viable constraint per state

Density sets the balance between the agent's identity and the graph's constraints:

- **Light state** — minimal constraints; the agent's expertise and character lead. Use where
  good judgment and natural flow serve the user.
- **Dense state** — many specific constraints; the graph dominates. Use only where
  consistency, compliance, or safety demand it.

A graph can and should mix light and dense states. Practical budget per state: roughly **2-6
actions**, **3-8 navigation guidelines**, exit conditions covering every real path. Far more
than that usually means two states. Don't state the obvious — a modern model already knows not
to be rude, and every unnecessary instruction wastes context and can confuse edge cases.

### Choose the least-constraining state type that fits

| State type | Talks to user? | Use when |
|---|---|---|
| **Action** | Yes (only client-visible type) | The agent must say something — speak, ask, guide, close. Carries `objective`, ordered `actions` (WHAT), `intra_state_navigation_guidelines` (how to move between actions), `action_guidelines` (HOW), `boundary_constraints` (hard nevers), `exit_conditions`. Every user-visible turn begins and ends here. |
| **Decision** | No (internal routing) | 2+ qualitatively different next paths and the choice can be written as criteria. Carries `decision_guidelines` + `exit_conditions` (no `actions`); picks an exit and transitions immediately; can serve as a central router. |
| **Data-collection** | Yes | The mode is specifically *gathering structured inputs* one at a time (name, then email, then phone) with confirmation before advancing. Keep the "one field at a time / confirm first" discipline here. |
| **Annotation** | No (invisible marker) | Record that an otherwise-implicit boundary was crossed (a phase started/completed). Purely organizational; transitions immediately. |

Prefer an action state's own guidelines over a decision state when routing is intuitive and
conversational; reach for a decision state only when the branch is non-obvious and benefits
from explicit criteria.

### Few-shot: an action state

The fields split cleanly — `actions` say *what* (high-level), `action_guidelines` say *how*,
`boundary_constraints` are hard nevers, `exit_conditions` are the ways out. A sanitized
appointment-reschedule state:

```json
{
  "confirm_reschedule": {
    "type": "action",
    "objective": "Confirm the caller's new appointment time and complete the reschedule",
    "actions": [
      "Offer the open slots that match the caller's stated preference",
      "Confirm the specific slot the caller chooses",
      "Complete the reschedule and read the new time back"
    ],
    "intra_state_navigation_guidelines": [
      "Start by offering slots; do not complete the reschedule until the caller confirms one.",
      "If the preference is too vague to match a slot, ask one focused question instead of guessing.",
      "Once the reschedule succeeds, read the new time back and move on."
    ],
    "action_guidelines": [
      "Offer at most three concrete slots at a time so the caller isn't overwhelmed.",
      "Filter the slots you present by the caller's stated day / time-of-day preference."
    ],
    "boundary_constraints": [
      "Never describe the appointment as moved until the reschedule tool returns success.",
      "Never book a new appointment or cancel one here — only move the existing one."
    ],
    "exit_conditions": [
      { "description": "The reschedule completed and the new time was confirmed", "next_state": "close_out" },
      { "description": "The caller no longer wants to reschedule", "next_state": "close_out" }
    ]
  }
}
```

**Actions are WHAT, not HOW.** Keep `actions` high-level and push detail/phrasing into
`action_guidelines`. Over-specifying an action bakes in exact options or wording, which makes
the agent repeat itself and breaks natural flow:

| ✗ Avoid (rigid) | ✓ Prefer (high-level) |
|---|---|
| `"Offer the 3 PM, 4 PM, or 5 PM slot by saying 'Which do you want — 3, 4, or 5?'"` | `"Offer open slots that match the caller's preference"` — with an `action_guideline`: `"Present matching slots gradually, using the caller's stated preference."` |

### Few-shot: a decision state (router)

A decision state is **invisible to the caller** — no `actions` or `action_guidelines`, just
`decision_guidelines` plus `exit_conditions`, and it transitions immediately. Use one as a
central router when several distinct modes could come next:

```json
{
  "route_support_request": {
    "type": "decision",
    "objective": "Determine what the caller needs and route to the right state",
    "decision_guidelines": [
      "Review the conversation so far to decide which request the caller is making.",
      "Prefer the most specific match; an unresolved billing question routes to billing first.",
      "If intent is still unclear, route back to intake to ask one clarifying question."
    ],
    "exit_conditions": [
      { "description": "The caller is asking about an existing order or delivery", "next_state": "handle_order_status" },
      { "description": "The caller has a billing or payment question", "next_state": "handle_billing" },
      { "description": "The caller wants to change or cancel a subscription", "next_state": "handle_subscription" },
      { "description": "The caller's intent is unclear", "next_state": "intake" }
    ]
  }
}
```

Keep each exit condition **distinct and non-overlapping**, and make the last one an explicit
catch-all so the router always has a safe default.

### Clear state naming

State names are visible to the agent and shape navigation quality. Apply the **pinpoint
test**: from the name alone, plus the service description, can you roughly pinpoint how the
state contributes to the service?

- **Use action verbs; be descriptive** (long is fine): `gather_presenting_concern`,
  `establish_desired_outcome`, `summarize_and_confirm_understanding`.
- **Match the service description's vocabulary** so topology maps onto the narrative.
- **Differentiate similar states with meaning**: `explore_surface_context` /
  `explore_deeper_beliefs`, not `explore_1` / `explore_2`.
- **For large graphs, use phase prefixes**: `agreement_get_topic`, `exploration_deep_beliefs`.
- **Avoid** generic names (`state_1`, `process`, `handle_user`), unexplained abbreviations,
  HOW-not-WHAT names, and version-y suffixes (`greeting_new`, `explore_v2`).

### Lean global guidelines

Global guidelines are injected into **every** state. Golden rule: *if it doesn't genuinely
apply to every single state, it is not global.* Convenience is not a reason to globalize.

- Put truly universal responsiveness/safety rules in global (e.g. "always address the client's
  immediate question before continuing the planned action").
- If a guideline applies to only some states, **duplicate it into those states** — deliberate
  duplication beats polluting states where it doesn't apply.
- If many states share a large body of guidelines, factor them into a **child graph** with its
  own scoped globals, not the top-level globals.
- Test each global item: Does it apply to every state? Would applying it in state X cause harm?
  Is it already covered by the agent's identity? Is it too obvious to state?

### One coherent instruction set per state

Keep the field hierarchy clean and non-conflicting:

- `objective` — the single testable completion contract.
- `actions` — high-level WHAT, ordered. Keep them high-level; detailed must-persist context
  belongs in `action_guidelines` (guidelines stay visible throughout the state).
- `action_guidelines` — HOW (tone, tailoring, strategy).
- `boundary_constraints` — hard limits that override everything.
- `exit_conditions` — distinct, non-overlapping, each with a clear description and target.

A pile of competing "HIGHEST PRIORITY" rules in one state is *the* anti-pattern —
**contradiction, not length, is the signal to split.** Make transitions carry a clean handoff:
write exit-condition descriptions to capture what was accomplished, and open a receiving
state's objective by naming the context it can assume, so the agent doesn't re-ask known
things. Guard exits explicitly ("only after X"), avoid overlapping descriptions, and don't let
a vague aside ("let's move on") trip a premature transition.

### When to split a state vs. push to a function or skill

Decide **where the complexity lives** before authoring states — prefer the earliest/cheapest
rung that holds (the placement cascade):

1. **Deterministic rule / lookup?** → a `function` or precomputed data a tool reads. Not a state.
2. **Well-defined, decomposable path?** → a workflow of states on a fixed path.
3. **Open-ended, model must decide mid-task?** → single agent + tools; minimal (even single-state) graph.
4. **One bounded, must-be-exact / high-stakes concern?** → an isolated `skill`; a light top-level state routes to it. Recognition stays on the strong model; prove parity before cutover; keep the old path as fallback.
5. **Several distinct bounded modes?** → a decision-style state routing to multiple `skill`s.

**Split a state** when objective, tone, or exit criteria diverge, or when merging creates
contradictions. **Push work out of the graph** when it's deterministic (function) or a single
bounded judgment that must be exact and independently testable (skill). Once an orchestrated
pattern stabilizes, push it *down* the gradient — a stabilized chain of tool calls becomes one
`function`; a repeated bounded sub-judgment becomes a `skill`. Keep identity/voice in the
agent's own globals, not scattered as per-state rules.

---

## Pre-flight checklist

- [ ] Agent identity/voice authored in the agent's own global instructions; not scattered across states.
- [ ] Single clear objective; kept distinct from identity, treated as lowest-priority driver.
- [ ] Action guidelines vs. boundary constraints separated; must-be-exact behavior routed out to a `skill`.
- [ ] Minimal viable constraint: built reductively; no obvious instructions; no competing "HIGHEST PRIORITY" rules.
- [ ] Explicit priority order stated so conflicts resolve deterministically.
- [ ] Each state passes "exists to ___ / complete when ___" in one sentence.
- [ ] Each state name passes the pinpoint test; least-constraining state type chosen.
- [ ] Density tuned per state (~2-6 actions, ~3-8 nav guidelines); light/dense mixed deliberately.
- [ ] Globals apply to *every* state; state-specific rules duplicated into the states that need them.
- [ ] Exit conditions distinct, specific, and carry sufficient handoff context.
- [ ] Deterministic work in a `function`; must-be-exact bounded work in a `skill`; not fragmented into states.

## Validate before pushing

```bash
forge validate --entity-type agent --env staging
forge validate --entity-type context_graph --env staging
```

Fix structural problems here before `forge platform push`. For placement decisions (agent vs.
context_graph vs. skill vs. function), see `/forge-agent-design`; for the end-to-end build and
version-set pinning, see `/forge-build-agent`.

## Sources

- Anthropic — *Building Effective Agents* — <https://www.anthropic.com/research/building-effective-agents>
- OpenAI — *A Practical Guide to Building Agents* (PDF) — <https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf>
- HumanLayer — *12-Factor Agents* — <https://github.com/humanlayer/12-factor-agents>
- Cognition / Walden Yan — *Don't Build Multi-Agents* — <https://cognition.com/blog/dont-build-multi-agents> · follow-up *Multi-Agents: What's Actually Working* — <https://cognition.com/blog/multi-agents-working>
