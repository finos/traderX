/**
 * Shared type contract for all Angular environment configurations.
 *
 * All three environment variants (environment.ts, environment.prod.ts,
 * environment.local.ts) must implement this interface. TypeScript will
 * produce a compile error if any variant is missing a required property,
 * preventing silent runtime failures in production builds.
 *
 * When adding a new environment property, update this interface first,
 * then add the property to all three variants.
 */
export interface Environment {
    production:      boolean;
    accountUrl:      string;
    refrenceDataUrl: string;   // note: intentional typo matches existing key name
    tradesUrl:       string;
    positionsUrl:    string;
    peopleUrl:       string;
    tradeFeedUrl:    string;
}
