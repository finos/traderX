export const environment = {
    production:         false,
    accountUrl:         `//${window.location.hostname}:18088`,
    refrenceDataUrl:    `//${window.location.hostname}:18085`,
    tradesUrl:          `//${window.location.hostname}:18092/trade/`,
    positionsUrl:       `//${window.location.hostname}:18090`,
    peopleUrl:          `//${window.location.hostname}:18089`,
    tradeFeedUrl:       `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/nats-ws`
};
