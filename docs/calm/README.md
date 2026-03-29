# TraderX CALM Architecture

This folder contains the CALM (Common Architecture Language Model) architecture definition for the TraderX trading system.

## Contents

- **[`trading-system.architecture.json`](trading-system.architecture.json)** - The complete CALM architecture model for TraderX
- **`docs/`** - Generated architecture documentation in Markdown format
  - [`trading-system-overview.md`](docs/trading-system-overview.md) - System-wide architecture overview
  - [`flow-overview.md`](docs/flow-overview.md) - Business flow diagrams and descriptions
- **`templates/`** - Handlebars templates for generating documentation from the CALM model
  - `architecture-overview.md.hbs` - Template for system overview
  - `flows-overview.md.hbs` - Template for flow documentation

## What is CALM?

CALM (Common Architecture Language Model) is a sibling project of TraderX within the FINOS family of open source projects. It provides a JSON-based declarative language for describing system architectures in regulated environments.

CALM enables:

- Machine-readable architecture definitions
- Automated architecture analysis and validation
- Compliance tracking through controls and metadata
- Integration with governance tools

**Learn more:** [CALM Documentation](https://calm.finos.org)

## Viewing the Architecture

**Option 1: Read the JSON directly**  
Open [`trading-system.architecture.json`](trading-system.architecture.json) in your editor to explore nodes, interfaces, relationships, and flows.

**Option 2: Read generated documentation**  
The `docs/` folder contains human-readable Markdown documentation generated from the CALM model.


## Architecture Model Structure

The TraderX CALM model includes:

- **Nodes** - Services, databases, and UI components
- **Interfaces** - APIs, WebSocket feeds, and database connections
- **Relationships** - How components interact and depend on each other
- **Flows** - Business processes like trade creation and position updates
- **Metadata** - Deployment information, technology stack, and documentation links


## Integration with TraderX Documentation

The CALM model complements TraderX's existing documentation:

- **C4 diagrams** in `docs/c4/` show visual architecture
- **Mermaid diagrams** in `docs/flows.md` show sequence flows
- **CALM model** provides machine-readable, compliance-ready architecture definition

Keep the CALM model synchronized with code and diagram changes.
