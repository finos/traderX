// This file can be replaced during build by using the `fileReplacements` array.
// `ng build` replaces `environment.ts` with `environment.prod.ts`.
// The list of file replacements can be found in `angular.json`.

export const environment = {
    production: false,
    accountUrl: 'http://' + window.location.hostname + '/account-service',
    refrenceDataUrl: 'http://' + window.location.hostname + '/reference-data',
    tradesUrl: 'http://' + window.location.hostname + '/trade-service/trade/',
    positionsUrl: 'http://' + window.location.hostname + '/position-service',
    peopleUrl: 'http://' + window.location.hostname + '/people-service/people',
    tradeFeedUrl: 'http://' + window.location.hostname + '/trade-feed/'
};

/*
 * For easier debugging in development mode, you can import the following file
 * to ignore zone related error stack frames such as `zone.run`, `zoneDelegate.invokeTask`.
 *
 * This import should be commented out in production mode because it will have a negative impact
 * on performance if an error is thrown.
 */
// import 'zone.js/plugins/zone-error';  // Included with Angular CLI.
