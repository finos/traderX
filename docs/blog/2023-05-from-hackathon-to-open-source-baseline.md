---
title: From London Hackathon to Open-Source Baseline
date: 2023-05-01
description: How TraderX moved from early internal prototyping into an open-source baseline with runnable services and multiple UI paths.
---

# From London Hackathon to Open-Source Baseline

Published: **May 2023**

TraderX did not start as a perfectly planned greenfield open-source project. The early shape came from practical prototyping work, including hackathon-style collaboration in London at BMO, where the goal was to turn an internal concept into a learning-oriented open-source base.

By May 2023, the repository began to show real structure:

- `Initial checkin` landed core service wiring (`#13`).
- Java build and corporate build support were improved (`#15`).
- Both Angular and React front-end variants were added (`#17`, `#19`).
- Trade ticket and feed workflow behavior were refined (`#20`, `#21`).
- Messaging and "corp-friendly" structure were reworked (`#22`).

This period set a lasting theme for TraderX: keep the stack understandable, runnable, and polyglot enough to teach integration concerns without requiring enterprise-scale setup on day one.

Even at this early stage, the long-term question was already visible: how do we preserve simplicity as the project grows?

That question eventually shaped almost every architectural decision that followed.
