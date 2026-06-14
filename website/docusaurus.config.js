// Docs at https://docusaurus.io/docs

const projectName = 'TraderX'
const projectSlug = 'traderX'
const docsUrl = process.env.DOCUSAURUS_URL || 'https://traderx.finos.org'
const docsBaseUrl = process.env.DOCUSAURUS_BASE_URL || '/'

function pathBrowserPolyfillPlugin() {
  return {
    name: 'path-browser-polyfill',
    configureWebpack() {
      return {
        resolve: {
          fallback: {
            path: require.resolve('path-browserify'),
          },
        },
      }
    },
  }
}

function mermaidZoomClientPlugin() {
  return {
    name: 'mermaid-zoom-client',
    getClientModules() {
      return [require.resolve('./src/mermaid-zoom-client.js')]
    },
  }
}


// GitHub repo configuration - update these for forks/branches
const repoOwner = 'finos';
// Allow override via environment (e.g., DOCS_BRANCH=feature-branch)
const repoBranch = process.env.DOCS_BRANCH || 'main';
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
  url: docsUrl,
  baseUrl: docsBaseUrl,
  trailingSlash: false,
  favicon: 'img/favicon/favicon-traderX.ico',
  projectName: `${projectName}`,
  organizationName: 'FINOS',
  customFields: {
    repoUrl: repoUrl,
  },
  scripts: ['https://buttons.github.io/buttons.js'],
  stylesheets: ['https://fonts.googleapis.com/css?family=Overpass:400,400i,700'],
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  themeConfig: {
    navbar: {
      title: `TraderX`,
      logo: {
        alt: 'TraderX Logo',
        src: 'img/favicon/favicon-traderX.ico',
      },
      items: [
        {to: '/docs/home', label: 'Overview', position: 'right'},
        {to: '/docs/spec-kit/getting-started-with-traderx', label: 'Getting Started', position: 'right'},
        {to: '/specs', label: 'Specs', position: 'right'},
        {to: '/docs/spec-kit/state-docs', label: 'State Docs', position: 'right'},
        {to: '/docs/adr', label: 'ADRs', position: 'right'},
        {to: '/docs/learning', label: 'Learning', position: 'right'},
        {type: 'search', position: 'right'},
        {
          href: repoUrl,
          label: 'GitHub',
          position: 'right',
        }
      ],
    },
    footer: {
      copyright: `Copyright © ${new Date().getFullYear()} Fintech Open Source Foundation.`,
      logo: {
        alt: 'Fintech Open Source Foundation Logo',
        src: 'img/finos/finos-white.png',
        href: 'https://finos.org'
      },
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Home',
              to: '/docs/home',
            },
            {
              label: 'Blog',
              to: '/docs/blog',
            },
            {
              label: 'Getting Started',
              to: '/docs/spec-kit/getting-started-with-traderx',
            },
            {
              label: 'Learning Paths',
              to: '/docs/learning-paths',
            },
            {
              label: 'Learning Guides',
              to: '/docs/learning',
            },
            {
              label: 'Specs',
              to: '/specs',
            },
            {
              label: 'Source Code',
              to: repoUrl,
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
          exclude: ['prompt-ideas/**', 'migration/**', 'migration/**/*', '**/migration/**', 'guide/adr/**', 'guide/adr/**/*'],
          editUrl:
            'https://github.com/finos/traderX/edit/main/website/',
          sidebarPath: require.resolve('./sidebars.js')
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        }
      }
    ]
  ],
  plugins: [
    [
      require.resolve('docusaurus-lunr-search'),
      {
        languages: ['en'],
      },
    ],
    [
      'docusaurus-plugin-llms',
      {
        docsDir: '../docs',
        includeBlog: false,
        generateLLMsTxt: true,
        generateLLMsFullTxt: true,
        generateMarkdownFiles: false,
        excludeImports: true,
        removeDuplicateHeadings: true,
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'traderspec-root-specs',
        path: '../specs',
        routeBasePath: 'specs',
        sidebarPath: require.resolve('./traderspec-root-specs.sidebars.js'),
        sidebarItemsGenerator: require('./plugins/specs-sidebar-items-generator'),
        remarkPlugins: [require('./plugins/remark-speckit-reference-links')],
        include: ['**/*.md'],
        editUrl: 'https://github.com/finos/traderX/edit/main/specs/',
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'traderspec-specify',
        path: '../.specify',
        routeBasePath: 'specify',
        sidebarPath: require.resolve('./traderspec-specify.sidebars.js'),
        include: ['memory/**/*.md'],
        editUrl: 'https://github.com/finos/traderX/edit/main/.specify/',
      },
    ],
    mermaidZoomClientPlugin,
    pathBrowserPolyfillPlugin,
  ],
};
