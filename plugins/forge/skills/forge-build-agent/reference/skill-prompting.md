# Authoring an Amigo skill (single Anthropic-model prompt + tools)

Companion to the `forge-build-agent` skill. Use this when you are writing a `skill`'s
system prompt and defining its tools. The skill body has the cascade; this file is the
prompt-and-tools deep reference.

---

## What a skill is

An Amigo **`skill` is a single Anthropic-model system prompt that uses tools.** So
"authoring a skill well" is two jobs:

1. Write that system prompt using Anthropic's prompt-engineering techniques.
2. Define its tools (each a forge `function`) so the model calls them correctly.

You author skills for **must-be-exact or bounded concerns** that a `context_graph` state
routes to (see the placement cascade). The skill's durable identity and behavior live in
its system prompt; the moment-to-moment request arrives as the incoming user turn. Domain
facts belong in the `context_graph`, not hardcoded into the prompt, so the prompt stays
stable across `version-set` bumps. Validate with `forge validate` and test with
`forge platform skill test` before you pin a version.

---

## System-prompt structure checklist

Apply Anthropic's techniques in roughly this priority order. Section the prompt with stable
XML tags and reuse the same tag names across every skill you author.

| # | Element | What to do | Why |
|---|---|---|---|
| 1 | **Role** | One crisp identity sentence at the top: "You are a scheduling assistant for Acme Corp that books, reschedules, and cancels appointments." Durable behavior only — no transient task detail. | A role focuses tone and behavior; even one sentence helps. |
| 2 | **Clear, direct instructions** | Spell out the job, allowed actions, and out-of-scope actions. Where order/completeness matters, write explicit numbered steps (verify identity -> look up record -> take action). | Treat the model like a brilliant new hire with no context on your norms. |
| 3 | **Context / motivation** | Attach a one-line rationale to key constraints ("Confirm the time back before booking, because booking is hard to reverse"). | Explaining *why* lets the model generalize to adjacent cases. |
| 4 | **Examples (multishot)** | 3-5 `<example>` blocks showing an ideal turn: user input -> optional reasoning -> tool call(s) -> final reply. Make them relevant, diverse, and cover at least one edge/failure case. | Examples are the most reliable lever for format, tone, and structure. |
| 5 | **Let it think** | For multi-step reasoning (triage, eligibility), add a light "reflect on tool results and plan the next step" and a self-check before the final answer. State the goal, not a rigid micro-plan. | The model's reasoning often exceeds a hand-written step list. |
| 6 | **Output format** | Say what TO do, not what NOT to do. Require a named XML tag, or use Structured Outputs / an `enum` tool for classification. Ask for a post-action summary explicitly if you want one. | Positive format specs and format indicators steer output reliably. |
| 7 | **Fallback / uncertainty** | Give an explicit out: "If the info isn't in the records or `context_graph`, say you don't have enough information and [ask / escalate] rather than guessing." | Permission to say "I don't know" sharply cuts hallucination. |

### XML sectioning (reuse these tags)

```
<role> one identity sentence </role>
<instructions> job, allowed/out-of-scope actions, numbered procedures </instructions>
<constraints> rules, each with a one-line rationale </constraints>
<examples>
  <!-- 3-5 filled turns (one an edge case); see the complete worked example below -->
  <example>
    User: "Move my Tuesday physical to later that week."
    Reasoning: one appointment on file; caller wants the same week, later.
    → appointments_open_slots(after="Tue", same_week=true)
    Reply: "I can move your Tuesday 9:00 AM physical to Thursday 3:00 PM or Friday 10:00 AM — which works?"
  </example>
</examples>
<output_format> positive spec; named tag or Structured Outputs </output_format>
```

Extra rules:

- Put long inputs and retrieved `context_graph` documents **near the top**, above the task
  instruction; wrap each in `<document>` / `<source>` / `<document_content>` tags. For long
  docs, ask the model to quote relevant passages before answering.
- Separate hidden reasoning from the user-facing reply (`<thinking>` / `<answer>` or the
  platform's reasoning channel) so internal reasoning never leaks into the customer turn.
- Use only sanitized placeholders in examples: Acme Corp / Example Health, `test-org`,
  `user@example.com`, `555-010-1234`, UUID `00000000-0000-0000-0000-000000000000`.
- Kill preambles with a direct instruction rather than by hand-writing the start of the
  reply ("Respond directly without preamble; don't start with 'Here is...'"). Note that
  forcing a tool call (below) already suppresses any text before the tool call.
- Ground factual skills in sources: instruct the skill to look up via its tools before
  making claims, cite sources, and forbid answering from general knowledge where accuracy
  is safety-critical (e.g. Example Health).

---

## Tool-definition best practices

Each tool the skill uses is a forge `function`. The **single highest-leverage authoring
move is an extremely detailed tool description.**

- **Description (3-4+ sentences per tool):** what the tool does, when it should and should
  **not** be used, what each parameter means and how it affects behavior, and any caveats —
  including what it does **not** return.
- **Parameters:** give each a clear `description`; use `enum` for closed sets; mark truly
  required params `required` (smaller/faster models otherwise infer missing values — mark
  required or instruct the skill to ask).
- **Names:** namespace by the `service`/resource the function hits (`orders_lookup_status`,
  `calendar_book_slot`) so selection stays unambiguous as the tool surface grows.
- **Consolidate:** prefer a few capable functions (an `action` param) over many
  near-duplicates; this reduces selection ambiguity.
- **Responses:** return only high-signal fields plus stable IDs (slugs/UUIDs) — just what
  the skill needs to decide its next step.
- **Robustness:** add `input_examples` for nested/format-sensitive inputs; add `strict: true`
  where schema conformance matters. Run `forge validate` to catch schema issues before
  shipping.

### Force vs. let the model choose

- **Default to `auto`** and steer with prose. Author trigger language at **normal intensity**
  ("Use `orders_lookup_status` when the user asks about an existing order") — not
  "CRITICAL / You MUST." Highly steerable models over-trigger on emphatic language.
- **Force** (`any` / a specific `tool`) only when the skill must always act through a tool on
  a turn and you don't need a natural-language preamble. Two caveats: forcing suppresses any
  text before the tool call, and forced tool use is incompatible with extended thinking
  (only `auto` / `none` are allowed there — `any` / `tool` return a 400).
- **Act vs. advise:** phrase imperatively when you want action ("Book the appointment," not
  "you could suggest booking"). Current models follow instructions literally — "can you suggest
  changes" yields suggestions, not action.
- Add a light parallel-tool-calls instruction for skills reading multiple independent
  sources, and an action-confirmation rule before hard-to-reverse operations (deletes,
  external sends).

---

## A worked example — putting it together

A complete bounded skill that a `context_graph` routes to when a caller wants to move an
existing appointment. Each section maps to a checklist row above: durable identity and rules
live in the prompt; domain facts arrive from the tools and the `context_graph`.

**System prompt:**

```xml
<role>
You are the appointment-reschedule assistant for Example Health. You move an existing
appointment to a new time and confirm it. You do not book first-time appointments, cancel
care, or give clinical advice.
</role>

<instructions>
Reschedule the caller's appointment in this order:
1. Confirm which appointment they mean with `appointments_list` — never guess when more than one is on file.
2. Offer open slots from `appointments_open_slots` that match their stated preference.
3. Only after the caller confirms a specific slot, move it with `appointments_reschedule`.
4. Read the new date and time back to the caller.
Out of scope: first-time booking, cancellations, or any clinical question — say so and hand back to the main line.
</instructions>

<constraints>
- Confirm the new time back to the caller before calling `appointments_reschedule`, because a reschedule is disruptive to reverse.
- Never describe a slot as booked until `appointments_reschedule` returns success.
- If identity was not verified upstream, ask them to verify first — do not proceed.
</constraints>

<examples>
  <example>
    User: "Can you move my Tuesday physical to later that week?"
    Reasoning: one upcoming appointment; caller wants the same week, later — list, then offer matching slots.
    → appointments_list()  →  one match: Tue 9:00 AM
    → appointments_open_slots(after="Tue", same_week=true)  →  Thu 3:00 PM, Fri 10:00 AM
    Reply: "I can move your Tuesday 9:00 AM physical to Thursday at 3:00 PM or Friday at 10:00 AM — which works?"
  </example>
  <example>  <!-- edge case: preference too vague to act on -->
    User: "Just push it to whenever works."
    Reasoning: no preference concrete enough to pick a slot safely; ask one focused question rather than guess.
    Reply: "Happy to — do you prefer mornings or afternoons, and is there a day that works best for you?"
  </example>
</examples>

<output_format>
Reply in one or two short sentences, offer at most three concrete slots at a time, and end with a
single question. Never say the change is done until the tool call returns success.
</output_format>
```

**Its `appointments_reschedule` tool (a forge `function`):**

```json
{
  "name": "appointments_reschedule",
  "description": "Move ONE existing appointment to a confirmed open slot and return the updated appointment. Use only after the caller has confirmed a specific slot returned by appointments_open_slots; do NOT use to book a first appointment or to cancel one. Returns the updated appointment with its new start time and a status — it does NOT notify the caller (a separate step handles that).",
  "input_schema": {
    "type": "object",
    "properties": {
      "appointment_id": { "type": "string", "description": "ID of the appointment to move (from appointments_list)." },
      "new_slot_id":    { "type": "string", "description": "ID of the confirmed open slot (from appointments_open_slots)." }
    },
    "required": ["appointment_id", "new_slot_id"]
  }
}
```

Why it works: a one-line role fixes scope; numbered instructions enforce confirm-before-mutate;
each constraint carries its rationale; the two `<example>`s cover the happy path and a vague-input
edge case; the tool description says when *not* to use it and what it does *not* return. Test on
synthetic fixtures before pinning: `forge platform skill test <skill-id> --file ./case_reschedule.json`.

---

## Choosing a model tier

Anthropic frames model choice around **capabilities, speed, cost, and effort.** Do not pin a
model ID in guidance — IDs, prices, limits, and effort names change. Keep tier decisions at
the **family** level and link Anthropic's live docs.

| Tier | Strengths | Trade-off | Good fit for a skill |
|---|---|---|---|
| **Opus** | Most capable; complex reasoning, long-horizon / high-autonomy work | Highest cost, moderate latency | The skill's hardest reasoning; must-be-exact judgment |
| **Sonnet** | Best balance of speed and intelligence; the common production default | Fast, mid cost | Most tool-using skills |
| **Haiku** | Fastest, most economical | Near-frontier for its class | High-volume, latency-sensitive, classification skills |

Anthropic also ships a top-of-line generation above the standard lineup for the most
demanding work — check the models overview for the current top model when you need maximum
capability.

**Authoring implications:**

- **Current models follow instructions literally — be explicit, don't over-steer.** State
  scope explicitly (a literal model won't silently generalize "apply to the first section"
  to all sections). Remove emphatic "CRITICAL / MUST" language written for older models — it
  causes over-triggering now. Prefer general reasoning instructions over prescriptive
  step-by-step recipes; watch for over-eager, unrequested abstractions and add minimalism
  guardrails if you see them.
- **Smaller/faster tiers benefit more from structure and examples.** A Haiku-tier
  classification skill wants tight schemas, enumerated labels, and worked examples; an
  Opus-tier open-ended skill needs less scaffolding and more room.
- **Tune `effort` before switching tiers.** `effort` trades intelligence for latency/cost
  *within one model* — raise it for multi-step reasoning and long agent loops, lower it for
  short, scoped work. If reasoning is shallow on a hard problem, raise effort rather than
  prompting around it. Thinking is also promptable ("use it only when it meaningfully
  improves the answer; when in doubt, respond directly").
- **Pick the tier the skill's hardest turn actually needs**, then validate — don't pick by
  vibes. Some models keep thinking always-on, some default it off; verify per-model at author
  time.
- **Keep prompts portable across upgrades:** express intent and scope explicitly, avoid hacks
  that only compensated for an older model, and re-tune tool-triggering and effort guidance
  when you move a skill to a new tier.

Model choice belongs in the skill/service configuration you push with forge — treat a tier
change like any other change: validate, test, and bump the `version-set`.

---

## Test the skill with `forge platform skill test`

Anthropic's most important step in choosing or tuning a model is **building a use-case
eval set and running your real prompts/data across it.** For a forge skill, that means
`forge platform skill test` plus your own fixtures — on **synthetic data only**.

```bash
# create the skill from its JSON definition (system prompt + tool schemas)
forge platform skill create --file ./verify_identity_skill.json

# validate the definition before testing
forge validate --entity-type skill --env staging

# run a single case (turn-by-turn); use sanitized placeholders in every fixture
forge platform skill test <skill-id> --file ./case_missing_info.json

# see where the skill is wired in before you change or pin it
forge platform skill references <skill-id>
```

Build a small fixture set that covers the happy path, each out-of-scope / missing-info case,
and every must-be-exact case to full coverage. Compare tiers by running the same fixtures
across candidates, weigh quality against cost, then pin the winning version with a
`version-set` (dry-run first, then `--apply`). Keep the old version live as fallback until
parity holds.

---

## Skill authoring checklist

- [ ] One-sentence role at top; durable behavior only.
- [ ] Clear, specific instructions; numbered steps where order matters; rationale on key constraints.
- [ ] 3-5 diverse `<example>` blocks with sanitized placeholders, including an edge case.
- [ ] Consistent XML sectioning; long inputs and `context_graph` docs near the top in `<document>` tags.
- [ ] Positive output-format spec (named tag or Structured Outputs / enum).
- [ ] Explicit "I don't know / escalate" fallback; grounding-in-sources for factual skills.
- [ ] Every tool: 3-4+ sentence description, per-param descriptions, enums, required fields, high-signal responses, namespaced names, `input_examples` / `strict` where it matters.
- [ ] `tool_choice: auto` + normal-intensity trigger prose by default; force only when necessary; imperative phrasing for action.
- [ ] Tier chosen for the hardest turn; `effort` tuned before switching tiers; prompt kept portable.
- [ ] `forge validate` + `forge platform skill test` on synthetic fixtures before pinning the `version-set`.

---

## Sources

- Anthropic — *Prompt engineering overview* — <https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview>
- Anthropic — *Prompting best practices* — <https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices>
- Anthropic — *Use XML tags* — <https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/use-xml-tags>
- Anthropic — *Chain of thought* — <https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-of-thought>
- Anthropic — *Tool use overview* — <https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/overview>
- Anthropic — *Define tools* — <https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/define-tools>
- Anthropic — *Reduce hallucinations* — <https://docs.anthropic.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations>
- Anthropic — *Choosing the right model* — <https://docs.anthropic.com/en/docs/about-claude/models/choosing-a-model>
- Anthropic — *Models overview* — <https://docs.anthropic.com/en/docs/about-claude/models/overview>
- Anthropic — *Writing tools for agents* — <https://www.anthropic.com/engineering/writing-tools-for-agents>
