import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebar: SidebarsConfig = {
  apisidebar: [
    {
      type: "doc",
      id: "trade-service/finos-traderx-trade-service",
    },
    {
      type: "category",
      label: "trade-order-controller",
      items: [
        {
          type: "doc",
          id: "trade-service/create-trade-order",
          label: "createTradeOrder",
          className: "api-method post",
        },
      ],
    },
  ],
};

export default sidebar.apisidebar;
