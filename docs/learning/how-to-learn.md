---
title: "How to learn with TraderX states"
---

# How to learn with TraderX states

Think of TraderX as a practical book whose chapters are working implementations. You begin with a small trading application, follow a request through it, and then change one part of the design at a time. The code gives you something to investigate; the lesson is being able to explain what changed, why it changed, and what evidence supports your conclusion.

Start with [the baseline chapter](/docs/learning/state-001-baseline-uncontainerized-parity) if you are new to TraderX. If you already know the application, choose a question in the [chapter index](/docs/learning) or [visual state diagram](/docs/learning-paths). Read the selected chapter's starting point before running it. Follow the declared predecessor links to fill gaps in your understanding.

## Choose a question, then a path

- **How does a trade become a position?** Begin at 001 and follow the request and event flow before adding infrastructure.
- **How do deployment and persistence change the design?** Follow the edge and harness chapters into application containerization and Docker Compose (004), PostgreSQL (005), and NATS (006).
- **How do I explain and extend behavior?** Continue through observability (007), market data (008), and order matching (009).
- **How do I run and develop the same application on a platform?** Follow Kubernetes (010), Tilt (011), and the C3 checkpoint (012).
- **Which integration problem do I want to investigate?** Branch from C3 to Radius (013) for platform abstraction or FDC3 (014) for application interoperability. Radius is not a prerequisite for FDC3.

The numbers identify states; they do not determine prerequisites or rank architectures. Solid arrows in the diagram follow the catalog's `previous` relationships. Dotted arrows highlight retained context. A convergence chapter explains how capabilities combine. If a chapter has several parents, it declares whether their knowledge is required together or whether they are alternative entry routes.

## Work through a chapter

1. Read the purpose, starting assumptions and before/after comparison. Explain the problem in your own words before looking at the chosen tool.
2. Learn the concepts. Keep them separate from runtime prerequisites: understanding a fill is different from installing Java.
3. Follow the linked quickstart in a disposable local environment. Run only one state at a time; generation uses shared output locations and runtimes can share ports. Use the quickstart's stop procedure when finished.
4. Follow the guided experiment. Record identifiers, timestamps, responses and persisted results. Open the linked architecture, flows and contracts where they explain an observation.
5. Try the uncertainty case. Decide what the evidence establishes and what remains unknown. A green indicator is the beginning of an investigation, not its conclusion.
6. Answer the assessment before reading its guidance. If your explanation cannot connect the observation to the objective, repeat the relevant step.
7. Choose an onward link from that chapter. Technical pages include a return link to the same learning guide so you can resume your place.

## Keep a small learning notebook

For each experiment, write four sentences: “I expected…”, “I observed…”, “This establishes…”, and “This does not establish…”. Add the state, source revision and identifiers needed to reproduce the observation. This makes the progression cumulative without repeating every earlier chapter.

A ticket opening does not submit a trade, and an order is not a fill. A request being accepted does not mean the operation completed. Use the current chapter’s observations to distinguish preparation, submission and the recorded business result.

## Learn with an agent

An agent can be your learning partner: help you choose a chapter, ask a useful question, explain a concept in another way, or examine the evidence you collected. The goal is for you to explain the system, not simply to watch an agent complete the steps.

Try this starting prompt:

> Be my TraderX learning partner. Ask about my goal and prior experience, then help me choose a chapter from the Learning Guide. Check the chapter’s actual predecessors. Ask me to predict an outcome before we run an experiment. Offer one hint at a time, let me attempt the explanation before discussing assessment guidance, and distinguish what we observed from what we inferred. Keep a short progress note so we can resume later.

### A session protocol for learning partners

1. **Orient.** Ask what the learner wants to understand and what they have already tried. Load the selected state’s purpose, maturity and incoming transitions. Use its diagnostic question to check prerequisites; link to the relevant predecessor when a gap appears. Do not assume prior knowledge from a state number.
2. **Predict.** Select an objective by its stable ID and ask the chapter’s prediction question. Let the learner explain their reasoning before showing the expected observation.
3. **Experiment together.** Agree who will run the documented step and in which environment. Prefer learner participation; execute commands only within the learner’s authorized scope. If no runtime is available, offer a clearly labeled reading exercise and leave runtime evidence unverified. Never invent command output or imply that reading the guide is an executed test.
4. **Help progressively.** Ask one focused question at a time. Use the first hint, wait for an attempt, and offer the next hint if needed. Probe the named misconception without treating it as true. If the learner requests a full explanation, provide it and invite them to apply it to a new example.
5. **Assess the evidence.** Ask for the chapter’s evidence, compare it with the mapped objective and assessment guidance, and ask the learner to explain any difference. Separate expected behavior, reported observations, directly inspected results and inferences. Treat a missing observation as unknown, not success or failure. Cite the relevant guide section or system reference when explaining a claim.
6. **Reflect and continue.** Ask what the experiment establishes and what it does not establish. Record an objective as demonstrated only when the learner explains it using adequate evidence. Choose an onward state from the declared relationships or revisit a prerequisite; do not automatically advance through numbered chapters.

### Resume without guessing

Keep a short session note with the state ID, documentation source revision, chosen predecessor route, objective IDs, attempted walkthrough step, evidence and its provenance, the learner’s explanation, remaining misconception or uncertainty, and the next agreed action. Mark each objective as **not attempted**, **practiced**, or **demonstrated**. Do not record secrets or private runtime data; retain only the identifiers or redacted observations needed for the lesson. Recheck the source revision when resuming with different documentation.

### Readable by people and software

Use [the machine-readable learning index](/learning/index.json) to discover every current chapter’s status, predecessor and next-state IDs, canonical source path, HTML guide, Markdown guide, and structured JSON contract. It identifies the source revision of the build. The [published schema](/learning/contract.schema.json) describes the contracts. URLs in the index resolve on the same site, including a PR preview; do not mix preview content with another revision from the live site.

Every chapter’s **Structured lesson JSON** link provides the exact state-local contract used to render that guide, including objectives, exercises, assessment guidance and coaching prompts. The **View Markdown** link exposes the same human-readable lesson without requiring JavaScript or diagram interpretation. [llms.txt](/llms.txt) provides broader documentation discovery. The JSON is a reading format, not a command-execution API; runtime actions still need the learner’s environment and authorization.

An agent should use the coaching prompts and assessment guidance to support understanding rather than present an answer key before the learner has tried. Human reviewers should trial a session with a novice explanation, a misconception and missing runtime evidence; assess whether the partner responds usefully and stays within what the evidence supports.

## Read maturity honestly

Implemented and released chapters provide runnable exercises. Planned chapters describe intended objectives and explicitly mark runtime exercises unavailable. An implemented label is not a production guarantee. Local demonstrations may use synthetic prices, simplified matching, external applications or incomplete failure coverage; read each chapter's limitations before generalizing its results.

The published guides are generated from state-local learning contracts. To improve a chapter, follow the [authoring contract](/docs/spec-kit/learning-contract). Automated checks enforce structure and navigation; human review must still establish that the lesson is understandable and the experiment supports its claims.
