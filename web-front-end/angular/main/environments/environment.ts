// This file can be replaced during build by using the `fileReplacements` array.
// `ng build` replaces `environment.ts` with `environment.prod.ts`.
// The list of file replacements can be found in `angular.json`.

import { Environment } from './environment.interface';

export const environment: Environment = {
    production:         false,
    accountUrl:         `//${window.location.host}/account-service`,
    refrenceDataUrl:    `//${window.location.host}/reference-data`,
    tradesUrl:          `//${window.location.host}/trade-service/trade/`,
    positionsUrl:       `//${window.location.host}/position-service`,
    peopleUrl:          `//${window.location.host}/people-service`,
    orderMatcherUrl:    `//${window.location.host}/order-matcher`,
    tradeFeedUrl:       `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/nats-ws`
};

/*
 * For easier debugging in development mode, you can import the following file
 * to ignore zone related error stack frames such as `zone.run`, `zoneDelegate.invokeTask`.
 *
 * This import should be commented out in production mode because it will have a negative impact
 * on performance if an error is thrown.
 */
// import 'zone.js/plugins/zone-error';  // Included with Angular CLI.
