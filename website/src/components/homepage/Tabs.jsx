import React from 'react';
import clsx from 'clsx';
import {Icon} from './Icons';
import {tabs} from './homepageData';
import styles from './TraderXHomepage.module.css';

export default function TabNav({activeTab, onTabChange}) {
  return (
    <div className={styles.tabBar}>
      <div className={styles.tabBarInner} role="tablist" aria-label="Homepage sections">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            id={`tab-${tab.id}`}
            type="button"
            role="tab"
            aria-selected={activeTab === tab.id}
            aria-controls={`panel-${tab.id}`}
            className={clsx(styles.tabButton, activeTab === tab.id && styles.tabButtonActive)}
            onClick={() => onTabChange(tab.id)}
          >
            <Icon name={tab.icon} />
            {tab.label}
          </button>
        ))}
      </div>
    </div>
  );
}
