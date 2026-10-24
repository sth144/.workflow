---
name: write-like-me
description: Draft short text in Sean's own voice instead of default assistant prose. Use when Sean asks you to write something brief that will go out under his name or from his account - Slack messages, DMs, commit messages, PR descriptions, Jira/Trello card text, issue reports, short emails, replies to a thread. Trigger phrases include "write this as me", "in my voice", "sound like me", "draft a message to", "reply to this for me", "write it like I would". For anything over a few paragraphs (blog posts, writeups, READMEs, docs) use longform-like-me. Not for how you talk to Sean in chat (that is covered by Response Style in CLAUDE.md).
argument-hint: (what to write, and where it is going)
---

# Write Like Sean

Derived from ~280 of Sean's actual prompts. The goal is text that reads like he
typed it in thirty seconds, not text that reads like an assistant polished it.

## The core shape

Short. Direct. Lowercase-ish. Concrete nouns, plain verbs.

He states the situation, states what he wants, stops. When something is broken
he reports the symptom, not a theory. When he wants something built he describes
the end state, not the implementation.

Real examples, unedited:

- `explode is grayed out`
- `commit and push please`
- `no no no I'm talking about the home assistant branch`
- `is everything pushed to origin master? Everything pushed, nothing lost?`
- `I want to just update the file on pc0 to reflect everything in the trello-groomer repo manifest. It's that simple. Everything in one file`
- `do you think it would make sense to have an API for trello groomer at this point?`
- `just do your best to get as much of this working as possible, and tell me what you need from me as briefly as possible`

## Rules

**Length tracks the ask.** A one-line request stays one line. Don't pad a simple
message into a paragraph, and don't add a closing line that restates it.

**Lead with the point.** No throat-clearing. No "I wanted to reach out about" or
"just following up on". Start with the thing.

**Sentence case, loosely held.** He often starts lowercase (`can you`, `is it
here?`, `how do I`). Mid-message he'll start a fresh sentence with a capital
after a short fragment. Don't force perfect capitalization, and don't fake typos
either.

**Fragments are fine.** `Now.` `Also,` `Two things.` `Done.` He uses these as
pivots between ideas constantly.

**Hedge his own ideas, not his instructions.** Proposals get `I think`, `maybe`,
`probably`, `I feel like`, `or something`, `I'm wondering if`. Instructions get
none of that: `push it`, `merge it`, `do both`, `just do it`.

**Ask for the other person's read.** He genuinely wants input: `what do you
think?`, `any ideas?`, `open to ideas`, `would this work?`, `just wondering`,
`is that normal?`. Use it when the message is a proposal.

**Politeness lands at the end, not the front.** `please` almost always trails:
`commit and push please`, `fix ring visibility and implement scale please`,
`can you separate the wall segments so I can delete individual ones?`.

**Parentheticals carry the detail.** He offloads clarification into parens
rather than another sentence: `(ie. put it in a secret yaml file locally or
something)`, `(I know MLS will be hard bc I don't have Apple TV)`.

**Frustration is plain, not performed.** When something is dumb he says it is
dumb and moves on: `that's stupid`, `That's lame`, `bruh`, `I feel like I'm
losing my mind`. Never sarcasm dressed up as politeness. Use this register only
when he's clearly annoyed, and never point it at a person - it's aimed at tools
and defaults.

**Credit is short and real.** `great progress.`, `omg. So much better.`,
`looking good.`, `it's incredible. Basically perfect.`, `nice`, `Good job.` One
beat, then the next ask.

## Vocabulary and tics

Uses: `ie.` (with the period, not i.e.), `btw`, `bc`, `whatnot`, `or something`,
`a ton`, `such that` (`make it such that when a light is on...`), `go ahead`,
`got it`, `alright`, `ok`, `yeah`, `hold on`, `re:`, `let's`, `we need to`,
`I want`, `how would I go about`.

Pronouns: `we` and `let's` for shared work in progress. `I` for what he wants.
`you` for what the other party owes him.

Avoids entirely: exclamation points (near zero), emoji, hype adjectives,
rhetorical questions used for effect, headers and bold inside a short message.

## Multi-item requests

When there is more than about three things, he switches to a flat bullet list.
Plain hyphens. No bold, no headers, no nesting, no numbering unless the order
matters. Each bullet is one imperative or one observation, often with a
parenthetical fix-up. Bullets can be long and run-on; that's fine.

    - the plants in the raised garden bed are not placed within the bed, take a look (I had moved the bed)
    - the AC should be square when viewed from above
    - in the living room, there is a piano for some reason, get rid of it
    - make the driveway a bit longer if possible, so it can fit a car at some point

If the list is a spec, he closes with a completion condition:
`Keep iterating and rechecking these requirements until they are satisfied.`

When answering several questions at once he inlines them: `1. go ahead; 2. got
it; 3. yes please`.

## Registers

**Asking for help with a tool or UI:** state what he did, what happened, ask the
question. `I clicked installed. No MCP`. `double clicking highlights the object,
but dragging does nothing`. `method 1 didn't work`. `still nothing`.

**Directing work:** end state first, constraints after. `I want this in master`.
`Always do this`. `As long as there's no security risk I always want the latest
in github`.

**Proposing:** hedged, ends in a question. `do you think it would make sense
to...`, `I think it's probably best to gitignore the mappings for my actual
house. What do you think?`

**Correcting:** blunt and immediate, no softening preamble. `no no no`, `what? No
I want to...`, `hold on. Wait, something is not right about this.`, `that was
absolutely not desired`.

**Following up on something slow:** impatient but not hostile. `bruh push it what
are you waiting for`, `How long is it going to take for us to get this stuff
pushed??`, `keep trying`, `try again`.

## Do not use

These are the tells that break the voice instantly:

- Em dashes. He uses periods, commas and parens. Never an em dash.
- `caveat`, `load-bearing`, `smoking gun`, `the thing is`, `worth noting`,
  `to be clear`, `let me be direct`, `here's the thing`, `that said`.
- `delve`, `leverage`, `robust`, `seamless`, `streamline`, `elevate`,
  `unlock`, `ensure`, `it's not X, it's Y`, `not just X but Y`.
- Section headers, bold labels, or tables in anything shorter than a page.
- A closing summary sentence. When the ask is stated, stop.
- Hedging an instruction (`you might want to consider possibly`). Either it's a
  request or it's an idea; pick one.
- Apologizing or thanking at length. `thanks` alone is fine, occasionally.
- Restating what the other person said back to them before responding.

## Before sending

Read the draft and ask: would he have typed this, or is it what a very helpful
assistant would type on his behalf? Cut every sentence that exists to be
courteous rather than to say something. If a paragraph could be a sentence, make
it a sentence.

If the draft is going somewhere public or to another person (Slack, a PR, a
ticket, an email), show it to Sean before sending it unless he already told you
to send it.
