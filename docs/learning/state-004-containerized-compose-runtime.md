---
title: "State 004: Containerized Compose Runtime (NGINX Ingress)"
pagination_prev: null
pagination_next: null
---

# State 004 Learning Guide

<!-- Generated from specs/004-containerized-compose-runtime/learning-contract.json; edit the source. -->

## Containerize the application, then run it with Compose

Installing every service runtime by hand makes an application hard to reproduce. This is the first state in the learning path that containerizes the TraderX application: its services and web frontend are packaged into container images instead of running as host-managed application processes. Docker Compose then defines how those containers run together, including configuration, networking, dependencies and NGINX ingress. For developers coming from the uncontainerized stack, the lesson is both how the application is packaged and how its containers are coordinated.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/004-containerized-compose-runtime.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The harness and proxied application depend on host-installed service runtimes.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 003-agentic-harness-foundation

[Predecessor guide](/docs/learning/state-003-agentic-harness-foundation)

- **Carry forward:** Add generated instructions, architecture context and contributor guidance for repeatable agent-assisted work.
- **Why move:** The harness and proxied application depend on host-installed service runtimes.
- **Add or revise:** Containerize the application services and web frontend, then use Docker Compose to run the containers together behind NGINX and check readiness.
- **Evidence to collect:** Identify a backend Dockerfile and the frontend Dockerfile, their built images and running containers, then show how Compose supplies the runtime wiring. The business workflow is retained while process placement changes. Container state, service readiness and successful booking are three different observations. A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.
- **Objectives:** `containerize-application`, `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The harness and proxied application depend on host-installed service runtimes. | Containerize the application services and web frontend, then use Docker Compose to run the containers together behind NGINX and check readiness. |

### Concepts before tools

- Containerization packages an application component and its runtime dependencies into an image. A Dockerfile describes how that image is built; a container is a running instance of an image.
- Docker Compose describes how multiple containers run together: which images to build or use, their environment settings, networks, ports and dependencies. Packaging an application into images and coordinating its containers are distinct responsibilities.
- Compose networking uses service names; localhost inside a container refers to that container. The Docker engine still runs on a host, and source generation or image builds can still require host tooling.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **containerize-application:** Trace a backend service and the web frontend from their Dockerfiles to built images and running containers, and distinguish image packaging from Compose runtime configuration.
- **trace-increment:** Map the retained trade workflow to Compose services and distinguish container state, readiness and a successful business result.
- **interpret-evidence:** Explain the evidence boundary: A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.

### Guided walkthrough

#### 1. inspect-containerization (available)

Objectives: `containerize-application`.

Generate state 004 using the quickstart. Under generated/code/target-generated, inspect account-service/Dockerfile.compose and web-front-end/angular/Dockerfile.compose. Identify the base image, the application artifacts copied or built into it, and the command that starts the component. Then follow the quickstart start command to build and run the stack. Use docker image ls and docker ps to identify the resulting images and containers, and compare their names and configuration with the generated Compose definition.

**Expected observation and meaning:** Application components that previously ran as host-managed processes now run from container images. The frontend image serves the production/static application. The Dockerfiles define image contents and startup behavior; Compose connects and configures the containers. A successful image build alone does not establish service readiness or a working trade flow.

Supporting material: [quickstart](/specs/containerized-compose-runtime/quickstart) · [runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology).

#### 2. observe (available)

Objectives: `trace-increment`.

Generate and start the Compose state using the quickstart. Run its status and smoke commands. Compare the Compose service names, exposed ports and dependencies with the topology, then submit a small trade through ingress.

**Expected observation and meaning:** The business workflow is retained while process placement changes. Container state, service readiness and successful booking are three different observations.

Supporting material: [quickstart](/specs/containerized-compose-runtime/quickstart) · [architecture](/specs/containerized-compose-runtime/system/architecture) · [runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology).

#### 3. challenge (available)

Objectives: `interpret-evidence`.

In the disposable local stack, restart one application container identified in the generated Compose file. Watch status and retry a read through ingress after readiness returns; do not blindly resubmit a timed-out trade.

**Expected observation and meaning:** A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.

Supporting material: [spec](/specs/containerized-compose-runtime/spec).

### Demonstrate your understanding

**Question (`containerize-application`):** What does containerizing the application add beyond having a Compose file, and which parts of the runtime come from each?

**Assessment guidance:** Use the backend and frontend you inspected to identify their Dockerfiles, image contents and running containers. Explain how Compose selects or builds those images and supplies runtime configuration, networking and dependencies. Do not describe Compose configuration alone as the packaging of application code.

**Question (`trace-increment`, `interpret-evidence`):** Why can Compose report running while the browser still receives an error?

**Assessment guidance:** Explain readiness and upstream dependencies using the restarted service. Show the later successful read and separately verify any uncertain trade.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `containerize-application`.

**Check the starting point:** How are the application services and frontend started in state 003, and where do their runtime dependencies live?

**Ask before the experiment:** Before building state 004, predict which information belongs in an application Dockerfile and which belongs in the Compose definition.

**Hints, in order:**

1. Start with one backend and the frontend: identify the base image, application artifacts and startup command in each Dockerfile.
2. Follow the images into the Compose services and identify the environment settings, networking and dependencies supplied when containers run.

**Misconception to probe (not a fact):** Adding a Compose file is the same as packaging the application, or all the application components were already containerized in the preceding learning state.

**Evidence to ask the learner for:** Ask for the two inspected Dockerfiles, their images and running container identities, and an explanation separating application packaging from Compose runtime wiring.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** What changes when localhost is evaluated inside a container rather than on your host?

**Ask before the experiment:** Predict what the browser will observe while a restarted backend is running but not yet ready.

**Hints, in order:**

1. Separate container process status from the readiness of its dependencies.
2. Trace the ingress request to that backend and compare its status before and after readiness returns.

**Misconception to probe (not a fact):** A running container establishes that the complete trading workflow is available.

**Evidence to ask the learner for:** Ask for container/readiness observations, the ingress read result and independent evidence for any uncertain trade.

### Scope and limitations

- A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [003-agentic-harness-foundation](/docs/learning/state-003-agentic-harness-foundation)
- Dotted-line parent(s): none
- Next state(s): [005-postgres-database-replacement](/docs/learning/state-005-postgres-database-replacement)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C0`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose)

## Rendered Code

- Generated branch: [code/generated-state-004-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-containerized-compose-runtime)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `003-agentic-harness-foundation`: [code/generated-state-003-agentic-harness-foundation...code/generated-state-004-containerized-compose-runtime](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-agentic-harness-foundation...code%2Fgenerated-state-004-containerized-compose-runtime)

## Plain-English Code Delta

- **Code focus:** Adds Dockerfiles and Compose assembly for all baseline services.
- **Runtime behavior:** Keeps behavior from state 002 but moves orchestration to containers.
- **Learning takeaway:** Establishes the containerized baseline that other architecture branches build from.

## Run This State

```bash
./scripts/start-state-004-containerized-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/containerized-compose-runtime](/specs/containerized-compose-runtime)
- Architecture: [/specs/containerized-compose-runtime/system/architecture](/specs/containerized-compose-runtime/system/architecture)
- Flows / topology: [/specs/containerized-compose-runtime/system/runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology)
- Research: [link](/specs/containerized-compose-runtime/research)
- Data model: [link](/specs/containerized-compose-runtime/data-model)
- Quickstart: [link](/specs/containerized-compose-runtime/quickstart)

