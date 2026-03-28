import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebar: SidebarsConfig = {
  apisidebar: [
    {
      type: "doc",
      id: "people-service/traderspec-peopleservice-webapi",
    },
    {
      type: "category",
      label: "UNTAGGED",
      items: [
        {
          type: "doc",
          id: "people-service/get-a-person-from-directory-by-logon-or-employee-id",
          label: "Get a person from directory by logon or employee ID",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "people-service/get-people-where-logon-id-or-full-name-contains-search-text",
          label: "Get people where logonId or fullName contains search text",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "people-service/validate-person-identity-by-logon-or-employee-id",
          label: "Validate person identity by logon or employee ID",
          className: "api-method get",
        },
      ],
    },
  ],
};

export default sidebar.apisidebar;
