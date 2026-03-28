import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebar: SidebarsConfig = {
  apisidebar: [
    {
      type: "doc",
      id: "trade-processor/trade-processor-traderx",
    },
    {
      type: "category",
      label: "UNTAGGED",
      items: [
        {
          type: "doc",
          id: "trade-processor/process-order",
          label: "processOrder",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "trade-processor/docs-root",
          label: "docsRoot",
          className: "api-method get",
        },
      ],
    },
  ],
};

export default sidebar.apisidebar;
