import React from 'react';
import {Icon} from './Icons';
import {ExternalLink, SmartLink} from './Links';
import {catalogSource} from './homepageData';
import styles from './TraderXHomepage.module.css';

export default function Footer() {
  return (
    <footer className={styles.footer}>
      <div className={styles.footerInner}>
        <div className={styles.footerBrand}>
          <img src="/img/finos/finos-blue.png" alt="FINOS" className={styles.footerFinosLogo} />
          <span />
          <div>
            <p>Copyright 2026 Fintech Open Source Foundation.</p>
            <small>
              Homepage state list sourced from{' '}
              <ExternalLink href={catalogSource.catalogUrl}>
                catalog/state-catalog.json
              </ExternalLink>
              .
            </small>
          </div>
        </div>
        <div className={styles.footerLinks}>
          <ExternalLink href={catalogSource.catalogUrl}>State Catalog</ExternalLink>
          <SmartLink to={catalogSource.generatedBranchesDocs}>Generated Branches</SmartLink>
          <ExternalLink href="https://github.com/finos/traderX">
            <Icon name="github" />
            Repository
          </ExternalLink>
          <ExternalLink href="https://calendar.finos.org">
            <Icon name="calendar" />
            Project Calls
          </ExternalLink>
        </div>
      </div>
    </footer>
  );
}
