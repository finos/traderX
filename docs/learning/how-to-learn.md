---
title: "How to learn with TraderX states"
---

# How to learn with TraderX states

Think of TraderX as a practical book whose chapters are working implementations. You begin with a small trading application, follow a request through it, and then change one part of the design at a time. The code gives you something to investigate; the lesson is being able to explain what changed, why it changed, and what evidence supports your conclusion.

Start with [the baseline chapter](/docs/learning/state-001-baseline-uncontainerized-parity) if you are new to TraderX. If you already know the application, choose a question in the [chapter index](/docs/learning) or [visual state diagram](/docs/learning-paths). Read the selected chapter's starting point before running it. Follow the declared predecessor links to fill gaps in your understanding.

## Choose a question, then a path

- **How does a trade become a position?** Begin at 001 and follow the request and event flow before adding infrastructure.
- **How do deployment and persistence change the design?** Follow the edge and harness chapters into Compose (004), PostgreSQL (005), and NATS (006).
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

A booked trade, a cash-payment instruction, a payment response and settlement are different facts. A ticket opening does not submit a trade. A request being accepted does not mean the operation completed. A future payment lesson must introduce these distinctions before an external application or blockchain mechanism and explain exactly which evidence supports requested, pending, rejected or confirmed outcomes.

## Read maturity honestly

Implemented and released chapters provide runnable exercises. Planned chapters describe intended objectives and explicitly mark runtime exercises unavailable. An implemented label is not a production guarantee. Local demonstrations may use synthetic prices, simplified matching, external applications or incomplete failure coverage; read each chapter's limitations before generalizing its results.

The published guides are generated from state-local learning contracts. To improve a chapter, follow the [authoring contract](/docs/spec-kit/learning-contract). Automated checks enforce structure and navigation; human review must still establish that the lesson is understandable and the experiment supports its claims.
