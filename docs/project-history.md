---
id: project-history
title: "Project History"
sidebar_label: History
---

# Project History & Release Notes

This page tracks major milestones, architectural changes, and notable releases for TraderX.

## 2026

### January 2026
- **Docs restructure**: Reorganized and clarified the docs to improve onboarding for both humans and agents
- **AI-friendly guidance**: Added `AGENTS.md` plus code review guidance to help agentic tools and contributors work consistently in this repo

## 2023

### OSFF 2023 (November)
- **Project debut**: TraderX was presented at the [Open Source in Finance Forum 2023](https://events.linuxfoundation.org/open-source-finance-forum-new-york/) keynote demo session
- **Initial architecture**: Established the core service mesh with Account, Position, Trade, and Reference Data services
- **Multi-runtime support**: Java/Spring Boot, Node.js/NestJS, .NET Core, and Angular/React frontends

### Initial Contribution
- **Database**: H2-based SQL database for accounts, trades, and positions
- **Account Service** (Java/Spring Boot): Account management and validation
- **Position Service** (Java/Spring Boot): Trade and position queries
- **Trade Service** (Java/Spring Boot): Trade submission and validation
- **Trade Processor** (Java/Spring Boot): Async trade processing via message feed
- **Reference Data** (Node/NestJS): Security/ticker lookup service
- **People Service** (.NET Core): User directory integration
- **Trade Feed** (Node/Socket.IO): Pub-sub message bus for trade events
- **Web Front-End**: Angular (full features) and React (trading/blotter) implementations

---

## Contributing to this page

When making **major changes** to TraderX (new services, architectural shifts, significant feature additions), please add an entry here. Minor bug fixes and routine maintenance do not need to be recorded.
