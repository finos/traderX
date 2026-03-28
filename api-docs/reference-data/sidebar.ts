import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebar: SidebarsConfig = {
  apisidebar: [
    {
      type: "doc",
      id: "reference-data/traderspec-reference-data-service",
    },
    {
      type: "category",
      label: "UNTAGGED",
      items: [
        {
          type: "doc",
          id: "reference-data/health-check",
          label: "Health check",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "reference-data/list-all-stocks",
          label: "List all stocks",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "reference-data/find-stock-by-ticker",
          label: "Find stock by ticker",
          className: "api-method get",
        },
      ],
    },
  ],
};

export default sidebar.apisidebar;
