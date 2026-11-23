# Security experiment data model

A Run contains a scenario ID, profile ID, configuration/source/image digests, timestamps, synthetic dataset version, initiating identity reference, observed decisions and final result. A Decision includes the control layer, correlation ID, action and attributable evidence reference. An Outcome records database/message effects after asynchronous settling, continued trading and recovery state. An Assessment connects objective, prediction, evidence and explanation.

A ControlMapping records catalog version, requirement, implementation, test, evidence, result and limitation. A result can be passed, failed, incomplete or unavailable; unavailable must never render as protected. Raw tokens, private keys and passwords are excluded. Authoritative outcomes must be collected outside the assumed-compromised process.
