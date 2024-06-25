import React from 'react';
import classnames from 'classnames';
import Layout from '@theme/Layout';
import clsx from 'clsx'
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './styles.module.css';
import Feature from '../components/feature';
import { features } from '../components/feature-config';
import FeaturesTwo from '../components/featuresTwo';
import { featuresTwo } from '../components/featuresTwo-config';
import HomepageFeatures from '../components/HomepageFeatures'

function Home() {
  const context = useDocusaurusContext();
  const {siteConfig = {}} = context;
  return (
    <Layout
      title={`${siteConfig.title}`}
      description={`${siteConfig.tagline}`}>
      <header className={classnames('hero hero--primary', styles.heroBanner)}>

        <div className="container">
        <img className={styles.featureImage} src='img/traderX/TraderX_Horizontal_BLK.svg' alt='TraderX Logo' />
          <div className={styles.buttons}>
            <Link
              className={classnames(
                'button button--outline button--secondary button--lg',
                styles.getStarted
              )}
              to={'docs/home'}>
              Docs
            </Link>
            <Link
              className={classnames(
                'button button--outline button--secondary button--lg',
                styles.getStarted
              )}
              to={'https://demo.traderx.finos.org'}>
              Live Demo
            </Link>
            <Link
              className={classnames(
                'button button--outline button--secondary button--lg',
                styles.getStarted
              )}
              to={'https://github.com/finos/traderX'}>
              GITHUB
            </Link>
          </div>
        </div>
      </header>
      <main>
        <HomepageFeatures />
        {/*
        {features && features.length && (
          <section className={styles.features}>
            <div className="container">
              <div className="row">
                {features.map((props, idx) => (
                  <Feature key={idx} {...props} />
                ))}
              </div>
            </div>
          </section>
        )}
        {featuresTwo && featuresTwo.length && (
          <section className={styles.members}>
            <div className="container">
              <div className="row row--center">
                <h2></h2>
              </div>
              <div className="row">
                {featuresTwo.map((props, idx) => (
                  <FeaturesTwo key={idx} {...props} />
                ))}
              </div>
            </div>
          </section>
        )}
                */}
      </main>
    </Layout>
  );
}

export default Home;