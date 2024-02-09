// This file can be replaced during build by using the `fileReplacements` array.
// `ng build` replaces `environment.ts` with `environment.prod.ts`.
// The list of file replacements can be found in `angular.json`.

export const environment = {
    production: false,
    accountUrl: 'https://' + window.location.hostname + '/account-service',
    refrenceDataUrl: 'https://' + window.location.hostname + '/reference-data',
    tradesUrl: 'https://' + window.location.hostname + '/trade-service/trade/',
    positionsUrl: 'https://' + window.location.hostname + '/position-service',
    peopleUrl: 'https://' + window.location.hostname + '/people-service/people',
    tradeFeedUrl: 'https://' + window.location.hostname,
    tradeFeedPath: '/trade-feed'
};

/*
 * For easier debugging in development mode, you can import the following file
 * to ignore zone related error stack frames such as `zone.run`, `zoneDelegate.invokeTask`.
 *
 * This import should be commented out in production mode because it will have a negative impact
 * on performance if an error is thrown.
 */
// import 'zone.js/plugins/zone-error';  // Included with Angular CLI.
