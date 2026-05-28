// State 002 overlay: route browser traffic through edge proxy endpoint.
export const environment = {
    production:         false,
    accountUrl:         `//${window.location.host}/account-service`,
    refrenceDataUrl:    `//${window.location.host}/reference-data`,
    tradesUrl:          `//${window.location.host}/trade-service/trade/`,
    positionsUrl:       `//${window.location.host}/position-service`,
    peopleUrl:          `//${window.location.host}/people-service`,
    tradeFeedUrl:       `//${window.location.host}`
};
