import React from 'react';
import Link from '@docusaurus/Link';

export function ExternalLink({href, className, children, ...props}) {
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className={className} {...props}>
      {children}
    </a>
  );
}

export function SmartLink({to, href, className, children, ...props}) {
  if (to) {
    return (
      <Link to={to} className={className} {...props}>
        {children}
      </Link>
    );
  }

  return (
    <ExternalLink href={href} className={className} {...props}>
      {children}
    </ExternalLink>
  );
}
