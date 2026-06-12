import React from 'react';
import clsx from 'clsx';
import styles from './TraderXHomepage.module.css';

export function Icon({name, className}) {
  const shared = {
    className: clsx(styles.icon, className),
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 2,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': 'true',
  };

  switch (name) {
    case 'blog':
      return (
        <svg {...shared}>
          <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
          <path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5z" />
          <path d="M8 7h8M8 11h8" />
        </svg>
      );
    case 'external':
      return (
        <svg {...shared}>
          <path d="M15 3h6v6" />
          <path d="M10 14 21 3" />
          <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
        </svg>
      );
    case 'branch':
      return (
        <svg {...shared}>
          <circle cx="6" cy="18" r="3" />
          <circle cx="18" cy="6" r="3" />
          <path d="M6 15V9a3 3 0 0 1 3-3h6" />
        </svg>
      );
    case 'layers':
      return (
        <svg {...shared}>
          <path d="m12 2 9 5-9 5-9-5 9-5Z" />
          <path d="m3 12 9 5 9-5" />
          <path d="m3 17 9 5 9-5" />
        </svg>
      );
    case 'route':
      return (
        <svg {...shared}>
          <circle cx="6" cy="19" r="3" />
          <path d="M9 19h8.5a3.5 3.5 0 0 0 0-7H6.5a3.5 3.5 0 0 1 0-7H15" />
          <circle cx="18" cy="5" r="3" />
        </svg>
      );
    case 'code':
      return (
        <svg {...shared}>
          <path d="m16 18 6-6-6-6" />
          <path d="m8 6-6 6 6 6" />
        </svg>
      );
    case 'bot':
      return (
        <svg {...shared}>
          <path d="M12 8V4H8" />
          <rect width="16" height="12" x="4" y="8" rx="2" />
          <path d="M2 14h2M20 14h2M9 13v2M15 13v2" />
        </svg>
      );
    case 'target':
      return (
        <svg {...shared}>
          <circle cx="12" cy="12" r="10" />
          <circle cx="12" cy="12" r="6" />
          <circle cx="12" cy="12" r="2" />
        </svg>
      );
    case 'handshake':
      return (
        <svg {...shared}>
          <path d="m11 17 2 2a2.8 2.8 0 0 0 4 0l4-4" />
          <path d="m2 12 5-5 5 5" />
          <path d="m7 7 4-4 10 10" />
        </svg>
      );
    case 'users':
      return (
        <svg {...shared}>
          <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
          <path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
      );
    case 'monitor':
      return (
        <svg {...shared}>
          <rect width="20" height="14" x="2" y="3" rx="2" />
          <path d="M8 21h8M12 17v4" />
        </svg>
      );
    case 'bolt':
      return (
        <svg {...shared}>
          <path d="M13 2 3 14h8l-1 8 11-14h-8l1-6Z" />
        </svg>
      );
    case 'github':
      return (
        <svg {...shared}>
          <path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5a10.6 10.6 0 0 0-5.5 0C8.5 2 7.5 2 7.5 2c-.3 1.15-.3 2.35 0 3.5A5.4 5.4 0 0 0 6.5 9c0 3.5 3 5.5 6 5.5A4.8 4.8 0 0 0 11 18v4" />
          <path d="M9 18c-4.5 2-5-2-7-2" />
        </svg>
      );
    case 'calendar':
      return (
        <svg {...shared}>
          <path d="M8 2v4M16 2v4" />
          <rect width="18" height="18" x="3" y="4" rx="2" />
          <path d="M3 10h18" />
        </svg>
      );
    case 'file':
      return (
        <svg {...shared}>
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <path d="M14 2v6h6" />
          <path d="M8 13h8M8 17h5" />
        </svg>
      );
    case 'diagram':
      return (
        <svg {...shared}>
          <rect width="7" height="5" x="3" y="3" rx="1" />
          <rect width="7" height="5" x="14" y="3" rx="1" />
          <rect width="7" height="5" x="8.5" y="16" rx="1" />
          <path d="M6.5 8v2.5H12V16M17.5 8v2.5H12" />
        </svg>
      );
    case 'flow':
      return (
        <svg {...shared}>
          <path d="M4 6h16M4 12h10M4 18h16" />
          <path d="m15 9 3 3-3 3" />
        </svg>
      );
    case 'book':
      return (
        <svg {...shared}>
          <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
          <path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5z" />
        </svg>
      );
    case 'decision':
      return (
        <svg {...shared}>
          <path d="M9 11 12 14 22 4" />
          <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
        </svg>
      );
    default:
      return null;
  }
}

export function TraderXLogo({large = false}) {
  return (
    <svg
      viewBox="0 0 100 100"
      className={large ? styles.logoLarge : styles.logo}
      aria-hidden="true"
    >
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M15 0C6.716 0 0 6.716 0 15v70c0 8.284 6.716 15 15 15h70c8.284 0 15-6.716 15-15V15c0-8.284-6.716-15-15-15H15zm0 8h70c3.866 0 7 3.134 7 7v70c0 3.866-3.134 7-7 7H15c-3.866 0-7-3.134-7-7V15c0-3.866 3.134-7 7-7z"
      />
      <polygon points="18,22 45,50 18,78" />
      <polygon points="82,22 55,50 82,78" />
      <polygon points="35,16 65,16 50,31" />
      <polygon points="35,84 65,84 50,69" />
    </svg>
  );
}
