// This is for running everything off of the local machine, connecting 
// to each service by its port number, not behind an aggregator/gateway
export const environment = {
    production:         false,
    accountUrl:         `//${window.location.hostname}:18088`,
    refrenceDataUrl:    `//${window.location.hostname}:18085`,
    tradesUrl:          `//${window.location.hostname}:18092/trade/`,
    positionsUrl:       `//${window.location.hostname}:18090`,
    peopleUrl:          `//${window.location.hostname}:18089`,
    tradeFeedUrl:       `//${window.location.hostname}:18086`
};
