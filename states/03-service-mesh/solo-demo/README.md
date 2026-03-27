# Level 3 - Service Mesh (Solo Demo)

## Objectives

- Provide a concrete, inspectable mesh demo layout.
- Encode static artifacts for mTLS, ingress/egress posture, canary, and observability.

## Structure

- `manifests/`: mesh and policy resources
- `scripts/`: setup, verify, teardown
- `observability/`: metric/dashboard stubs

## Run

```bash
./states/03-service-mesh/solo-demo/scripts/setup.sh
```

## Verify

```bash
./states/03-service-mesh/solo-demo/scripts/verify.sh
```

## Teardown

```bash
./states/03-service-mesh/solo-demo/scripts/teardown.sh
```

## Validation Prompt

Use `prompts/validation/mesh-sanity-check.md` for dynamic cluster validation or static manifest review.
