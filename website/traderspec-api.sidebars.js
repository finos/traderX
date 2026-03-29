module.exports = {
  "traderspecApiSidebar": [
    {
      "type": "category",
      "label": "API Explorer",
      "link": {
        "type": "doc",
        "id": "index"
      },
      "items": [
        {
          "type": "category",
          "label": "Account Service",
          "items": [
            {
              "type": "category",
              "label": "Operations",
              "items": [
                {
                  "type": "doc",
                  "id": "account-service/create-account-user"
                },
                {
                  "type": "doc",
                  "id": "account-service/create-account"
                },
                {
                  "type": "doc",
                  "id": "account-service/get-account-by-id"
                },
                {
                  "type": "doc",
                  "id": "account-service/get-account-users-by-account-id"
                },
                {
                  "type": "doc",
                  "id": "account-service/list-account-users"
                },
                {
                  "type": "doc",
                  "id": "account-service/list-accounts"
                },
                {
                  "type": "doc",
                  "id": "account-service/update-account-user"
                },
                {
                  "type": "doc",
                  "id": "account-service/update-account"
                }
              ]
            }
          ],
          "link": {
            "type": "doc",
            "id": "account-service/account-service-traderx-spec-first"
          }
        },
        {
          "type": "category",
          "label": "People Service",
          "items": [
            {
              "type": "category",
              "label": "Operations",
              "items": [
                {
                  "type": "doc",
                  "id": "people-service/get-a-person-from-directory-by-logon-or-employee-id"
                },
                {
                  "type": "doc",
                  "id": "people-service/get-people-where-logon-id-or-full-name-contains-search-text"
                },
                {
                  "type": "doc",
                  "id": "people-service/validate-person-identity-by-logon-or-employee-id"
                }
              ]
            }
          ],
          "link": {
            "type": "doc",
            "id": "people-service/traderspec-peopleservice-webapi"
          }
        },
        {
          "type": "category",
          "label": "Position Service",
          "items": [
            {
              "type": "category",
              "label": "Operations",
              "items": [
                {
                  "type": "doc",
                  "id": "position-service/get-all-positions"
                },
                {
                  "type": "doc",
                  "id": "position-service/get-all-trades"
                },
                {
                  "type": "doc",
                  "id": "position-service/get-positions-by-account-id"
                },
                {
                  "type": "doc",
                  "id": "position-service/get-trades-by-account-id"
                },
                {
                  "type": "doc",
                  "id": "position-service/health-alive"
                },
                {
                  "type": "doc",
                  "id": "position-service/health-ready"
                }
              ]
            }
          ],
          "link": {
            "type": "doc",
            "id": "position-service/finos-traderx-position-service-spec-first"
          }
        },
        {
          "type": "category",
          "label": "Reference Data",
          "items": [
            {
              "type": "category",
              "label": "Operations",
              "items": [
                {
                  "type": "doc",
                  "id": "reference-data/find-stock-by-ticker"
                },
                {
                  "type": "doc",
                  "id": "reference-data/health-check"
                },
                {
                  "type": "doc",
                  "id": "reference-data/list-all-stocks"
                }
              ]
            }
          ],
          "link": {
            "type": "doc",
            "id": "reference-data/traderspec-reference-data-service"
          }
        },
        {
          "type": "category",
          "label": "Trade Processor",
          "items": [
            {
              "type": "category",
              "label": "Operations",
              "items": [
                {
                  "type": "doc",
                  "id": "trade-processor/docs-root"
                },
                {
                  "type": "doc",
                  "id": "trade-processor/process-order"
                }
              ]
            }
          ],
          "link": {
            "type": "doc",
            "id": "trade-processor/trade-processor-traderx"
          }
        },
        {
          "type": "category",
          "label": "Trade Service",
          "items": [
            {
              "type": "category",
              "label": "Operations",
              "items": [
                {
                  "type": "doc",
                  "id": "trade-service/create-trade-order"
                }
              ]
            }
          ],
          "link": {
            "type": "doc",
            "id": "trade-service/finos-traderx-trade-service"
          }
        }
      ]
    }
  ]
};
