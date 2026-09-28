import React from 'react';
import { Link } from 'react-router-dom';

const LINKS = [
  { label: 'Terms & Conditions', to: '/legal/terms' },
  { label: 'Privacy Policy',     to: '/legal/privacy' },
  { label: 'Guides',             to: '/legal/guides' },
  { label: 'Help',               to: '/legal/support' },
];

// Shared footer for auth pages (Login / Signup) — legal links + brand credit.
const AuthFooter = () => (
  <div className="mt-10 pb-6 text-center text-[12px] text-gray-500 dark:text-gray-400">
    <div className="flex flex-wrap justify-center gap-x-3 gap-y-1.5 mb-2">
      {LINKS.map((l, i) => (
        <React.Fragment key={l.to}>
          {i > 0 && <span className="text-gray-300 dark:text-gray-700">•</span>}
          <Link to={l.to} className="hover:underline">{l.label}</Link>
        </React.Fragment>
      ))}
    </div>
    <p>
      © 2026 B-Smart from{' '}
      <a
        href="https://ruvees.in/"
        target="_blank"
        rel="noopener noreferrer"
        className="hover:underline"
      >
        Ruvees IT Solutions
      </a>
    </p>
  </div>
);

export default AuthFooter;
