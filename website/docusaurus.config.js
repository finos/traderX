// Docs at https://docusaurus.io/docs

const projectName = 'TraderX'
const projectSlug = 'traderX'
const copyrightOwner = 'FINOS - The Fintech Open Source Foundation'

// GitHub repo configuration - update these for forks/branches
const repoOwner = 'finos';
const repoBranch = 'main';
const repoUrl = `https://github.com/${repoOwner}/${projectSlug}`;

// Remark plugin to transform relative links to GitHub URLs
const transformRelativeLinks = require('./src/remark/transformRelativeLinks');

module.exports = {
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  onBrokenLinks: 'ignore',
  title: `${projectName}`,
  tagline: `${projectName}`, 
  url: 'https://finos.org',
  baseUrl: '/',
  trailingSlash: false,
  favicon: 'img/favicon/favicon-traderX.ico',
  projectName: `${projectName}`,
  organizationName: 'FINOS',
  customFields: {
    repoUrl: repoUrl,
  },
  scripts: ['https://buttons.github.io/buttons.js'],
  stylesheets: ['https://fonts.googleapis.com/css?family=Overpass:400,400i,700'],
  themeConfig: {
    navbar: {
      title: `TraderX`,
      logo: {
        alt: 'TraderX Logo',
        src: 'img/favicon/favicon-traderX.ico',
      },
      items: [
        {to: 'docs/home', label: 'Docs', position: 'right'},
        {to: 'docs/roadmap', label: 'Roadmap', position: 'right'},
        {to: 'docs/project-history', label: 'History', position: 'right'},
        {
          href: 'https://github.com/finos/',
          label: 'GitHub',
          position: 'right',
        }
      ],
    },
    footer: {
      copyright: `Copyright © ${new Date().getFullYear()} TraderX - ${copyrightOwner}`,
      logo: {
        alt: 'FINOS Logo',
        src: 'img/favicon/favicon-finos.ico',
        href: 'https://finos.org'
      },
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Getting Started',
              to: 'docs/home',
            },
            {
              label: 'Roadmap',
              to: 'docs/roadmap',
            },
            {
              label: 'Project History',
              to: 'docs/project-history',
            }
          ]
        },
        {
          title: 'FINOS',
          items: [
            {
              label: 'FINOS Website',
              to: 'https://www.finos.org/',
            },
            {
              label: 'Community Handbook',
              to: 'https://community.finos.org/',
            },
            {
              label: 'FINOS Projects',
              to: 'https://landscape.finos.org',
            }
          ]
        },
        {
          title: 'About FINOS',
          items: [
            {
              label: 'FINOS Projects on GitHub',
              to: 'https://github.com/finos',
            },
            {
              label: 'Engage the FINOS Community',
              to: 'https://www.finos.org/engage-with-our-community',
            },
            {
              label: 'FINOS News and Events',
              to: 'https://www.finos.org/news-and-events',
            }
          ]
        },
      ]
    },
  },
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          path: '../docs',
          editUrl:
            `${repoUrl}/edit/${repoBranch}/`,
          sidebarPath: require.resolve('./sidebars.js'),
          remarkPlugins: [
            [transformRelativeLinks, { repoUrl, branch: repoBranch }],
          ],
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        }
      }
    ]
  ]
};
