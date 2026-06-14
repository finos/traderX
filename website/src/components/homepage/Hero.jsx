import React from 'react';
import Link from '@docusaurus/Link';
import {Icon} from './Icons';
import {ExternalLink} from './Links';
import {catalogSource, internalNav} from './homepageData';
import styles from './TraderXHomepage.module.css';

function TopBanner() {
  return (
    <div className={styles.topBanner}>
      Welcome to the new TraderX docs. Read the{' '}
      <Link to="/docs/blog/2026-03-29-traderx-speckit-migration">
        engineering migration story
      </Link>
      .
    </div>
  );
}

function HeroNav() {
  return (
    <nav className={styles.heroNav} aria-label="Homepage">
      <Link to="/" className={styles.brand}>
        <img src="/img/favicon/favicon-traderX.ico" alt="" className={styles.brandLogo} />
        <span>FINOS TraderX</span>
      </Link>

      <div className={styles.navLinks}>
        {internalNav.map((item) => (
          <Link key={item.to} to={item.to} className={styles.navLink}>
            {item.label === 'Blog' && <Icon name="blog" />}
            {item.label}
          </Link>
        ))}
        <ExternalLink href="https://github.com/finos/traderX" className={styles.navLink}>
          GitHub
          <Icon name="external" />
        </ExternalLink>
        <ExternalLink href="https://www.finos.org" className={styles.finosNavBadge}>
          <img src="/img/finos/finos-white.png" alt="" />
          <span>FINOS</span>
        </ExternalLink>
      </div>
    </nav>
  );
}

export default function Hero() {
  return (
    <>
      <TopBanner />
      <header className={styles.hero}>
        <HeroNav />
        <div className={styles.heroContent}>
          <div className={styles.heroKicker}>
            <Icon name="branch" />
            Spec-Driven Reference Architecture Portal
          </div>

          <div className={styles.heroTitleGroup}>
            <img
              src="/img/traderX/TraderX_Horizontal_BLK.svg"
              alt="TraderX"
              className={styles.heroLogo}
            />
          </div>

          <p className={styles.heroCopy}>
            TraderX has evolved from a monolithic codebase into a comprehensive{' '}
            <Link to={catalogSource.learningPaths}>Knowledge Graph</Link>. Powered by
            Spec-Driven Development, it serves as the ultimate Pet Store for testing, learning, and
            integrating FINOS standards across parallel architectural states.
          </p>

          <div className={styles.heroActions}>
            <Link to={catalogSource.liveEnvironmentsDocs} className={styles.primaryAction}>
              Live Demos
            </Link>
            <ExternalLink href="https://github.com/finos/traderX" className={styles.secondaryAction}>
              GitHub Repository
            </ExternalLink>
          </div>
        </div>
      </header>
    </>
  );
}
