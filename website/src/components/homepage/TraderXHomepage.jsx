import React, {useState} from 'react';
import Head from '@docusaurus/Head';
import Hero from './Hero';
import TabNav from './Tabs';
import ActivePanel from './Sections';
import Footer from './Footer';
import styles from './TraderXHomepage.module.css';

export default function TraderXHomepage() {
  const [activeTab, setActiveTab] = useState('what');

  return (
    <>
      <Head>
        <title>TraderX | The FINOS Innovation Sandbox</title>
        <meta
          name="description"
          content="TraderX is the FINOS innovation sandbox for spec-driven learning states, live demos, and integration experiments."
        />
      </Head>
      <div className={styles.page}>
        <Hero />
        <TabNav activeTab={activeTab} onTabChange={setActiveTab} />
        <main className={styles.main}>
          <ActivePanel activeTab={activeTab} />
        </main>
        <Footer />
      </div>
    </>
  );
}
