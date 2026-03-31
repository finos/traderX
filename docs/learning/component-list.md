# Component List

State: `003-containerized-compose-runtime`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `trader` | Trader Browser | actor | User traffic enters through ingress. |
| `ingress` | NGINX Ingress | gateway | Compose ingress for UI/API/WebSocket routes. |
| `web` | Web Front End Angular | frontend | Containerized Angular service. |
| `account` | Account Service | service | Containerized Spring service. |
| `position` | Position Service | service | Containerized Spring service. |
| `tradeService` | Trade Service | service | Containerized Spring service. |
| `referenceData` | Reference Data | service | Containerized Node service. |
| `people` | People Service | service | Containerized .NET service. |
| `tradeFeed` | Trade Feed | messaging | Containerized Socket.IO bus. |
| `tradeProcessor` | Trade Processor | service | Containerized Spring service. |
| `database` | Database | database | Containerized H2 persistence service. |
