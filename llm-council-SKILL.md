---
name: llm-council
description: >
  Runs any question or decision through Karpathy's LLM Council methodology:
  multiple independent AI advisors give first opinions, anonymously peer-review
  each other's responses, then a Chairman synthesizes a final answer.
  Use this skill whenever the user asks for a "council", "second opinion",
  "multi-perspective answer", "devil's advocate", or says something like
  "what would different experts think?", "stress-test this", "challenge my
  thinking", or "give me multiple views on X". Also trigger for high-stakes
  decisions, complex trade-offs, or any question where bias or blind spots
  are a concern. Produces a structured HTML or Markdown report with all
  advisor outputs, peer reviews, and the Chairman's synthesis.
---

# LLM Council Skill

Implements [Andrej Karpathy's LLM Council](https://github.com/karpathy/llm-council) methodology entirely inside Claude using the Anthropic API. Instead of routing to multiple LLM providers, this skill spawns multiple *advisor personas* — each with a distinct thinking style — via separate API calls, has them critique each other anonymously, then synthesizes a final answer.

## Why this exists

Claude is highly agreeable. Ask "is this a good idea?" and it will say yes. Ask "is this a bad idea?" and it will say yes again. For real decisions, you want independent perspectives that can disagree and catch blind spots. The council forces that.

---

## The Three Stages

### Stage 1 — First Opinions
Each advisor receives only the user's original question (no other advisor's output). They respond independently with their best analysis.

### Stage 2 — Anonymous Peer Review
Each advisor is shown the other advisors' responses **with identities stripped** (labeled Advisor A, B, C…). They rank the responses by accuracy and insight and explain their reasoning.

### Stage 3 — Chairman Synthesis
The Chairman sees all first opinions AND all peer reviews. They produce one final, authoritative answer that incorporates the strongest points and notes where advisors disagreed.

---

## Advisor Personas

Use these five by default. Omit or swap based on the domain.

| Role | Thinking Style | System Prompt Seed |
|---|---|---|
| **Contrarian** | Finds the strongest case *against* the consensus | "You are a rigorous skeptic. Your job is to steelman the opposing view and identify weaknesses in the conventional answer." |
| **First Principles** | Breaks everything down to fundamentals | "Ignore analogies and conventional wisdom. Reason from first principles only." |
| **Expansionist** | Explores adjacent ideas, second-order effects | "Think broadly. What are the non-obvious implications, related domains, and long-term consequences?" |
| **Outsider** | Applies a domain completely different from the question | "You are an expert from a completely different field. Apply your domain's frameworks to this problem." |
| **Executor** | Focuses on practical implementation | "Cut the theory. What would actually work in practice? What are the concrete next steps and real-world constraints?" |

The **Chairman** should be prompted as: "You are a wise synthesizer. You have read all advisors' opinions and their peer reviews. Produce the single best answer: acknowledge genuine disagreements, integrate the strongest points, and be concrete."

---

## Implementation — Anthropic API Calls

Use `claude-sonnet-4-20250514` for all calls. Set `max_tokens: 1000` per call.

### Stage 1 call pattern (repeat for each advisor)

```javascript
{
  model: "claude-sonnet-4-20250514",
  max_tokens: 1000,
  system: "<advisor system prompt from table above>",
  messages: [
    { role: "user", content: userQuestion }
  ]
}
```

### Stage 2 call pattern (repeat for each advisor)

Strip advisor names from the compiled responses before passing them in. Label them "Advisor A", "Advisor B", etc.

```javascript
{
  model: "claude-sonnet-4-20250514",
  max_tokens: 1000,
  system: "<same advisor system prompt>",
  messages: [
    {
      role: "user",
      content: `Original question: ${userQuestion}\n\nHere are responses from other advisors (identities hidden):\n\n${anonymizedResponses}\n\nRank these responses from most to least insightful and explain your reasoning. Be critical.`
    }
  ]
}
```

### Stage 3 call pattern (Chairman)

```javascript
{
  model: "claude-sonnet-4-20250514",
  max_tokens: 1000,
  system: "You are a wise synthesizer. Read all advisor opinions and peer reviews carefully. Produce the single best, most complete answer. Where advisors genuinely disagreed, acknowledge it. Be concrete and direct.",
  messages: [
    {
      role: "user",
      content: `Question: ${userQuestion}\n\n--- ADVISOR FIRST OPINIONS ---\n${allFirstOpinions}\n\n--- PEER REVIEWS ---\n${allPeerReviews}\n\nNow produce the final synthesized answer.`
    }
  ]
}
```

---

## Output Format

Present results as an **interactive HTML artifact** with:

1. **Header** — the original question
2. **Advisor Tab View** — one tab per advisor showing their Stage 1 response
3. **Peer Review Section** — collapsible, showing each advisor's rankings and comments
4. **Chairman's Synthesis** — prominent, full-width final answer at the bottom

Use a clean card/tab layout. The Chairman's synthesis should be visually distinct (e.g., different background color).

If the user prefers Markdown, output:
```
## 🏛️ LLM Council — [Question]

### Advisor Opinions
**Contrarian:** ...
**First Principles:** ...
[etc.]

### Peer Reviews
**Contrarian's ranking:** ...
[etc.]

### ✅ Chairman's Synthesis
...
```

---

## When to use fewer advisors

- Simple factual questions → skip the council, answer directly
- 3-advisor version (Contrarian + First Principles + Executor) is enough for most decisions
- 5-advisor version for major decisions, research questions, or anything with high stakes

---

## Error handling

- If an API call fails, mark that advisor as "unavailable" and proceed with the rest
- If fewer than 2 advisors respond, abort and explain the issue to the user
- Strip any advisor self-identification from Stage 2 inputs (search for the persona names and replace with "Advisor X")

---

## Quick reference — trigger phrases

Trigger this skill when the user says any of:
- "council", "multi-perspective", "multiple views", "devil's advocate"
- "stress-test", "challenge my thinking", "second opinion"
- "what would experts think", "different angles", "am I missing something"
- "should I [do important thing]", "help me decide", "pros and cons" (for non-trivial decisions)
