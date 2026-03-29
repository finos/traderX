// This file can be replaced during build by using the `fileReplacements` array.
// `ng build` replaces `environment.ts` with `environment.prod.ts`.
// The list of file replacements can be found in `angular.json`.

export const environment = {
    production:         false,
    accountUrl:         `//${window.location.hostname}:18088`,
    refrenceDataUrl:    `//${window.location.hostname}:18085`,
    tradesUrl:          `//${window.location.hostname}:18092/trade/`,
    positionsUrl:       `//${window.location.hostname}:18090`,
    peopleUrl:          `//${window.location.hostname}:18089`,
    tradeFeedUrl:       `//${window.location.hostname}:18086`
};

/*
 * For easier debugging in development mode, you can import the following file
 * to ignore zone related error stack frames such as `zone.run`, `zoneDelegate.invokeTask`.
 *
 * This import should be commented out in production mode because it will have a negative impact
 * on performance if an error is thrown.
 */
// import 'zone.js/plugins/zone-error';  // Included with Angular CLI.
