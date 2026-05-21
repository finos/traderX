// Docs at https://docusaurus.io/docs

const projectName = 'TraderX'
const projectSlug = 'traderX'
const copyrightOwner = 'FINOS - The Fintech Open Source Foundation'
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


module.exports = {
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
    repoUrl: `https://github.com/finos/${projectSlug}`,
  },
  scripts: ['https://buttons.github.io/buttons.js'],
  stylesheets: ['https://fonts.googleapis.com/css?family=Overpass:400,400i,700'],
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  themeConfig: {
    announcementBar: {
      id: 'traderx-v2-welcome',
      backgroundColor: '#0b3a5e',
      textColor: '#ffffff',
      isCloseable: false,
      content:
        'Welcome to the new <strong>TraderX</strong> docs. Read the <a href="/docs/blog/2026-03-29-traderx-speckit-migration"><strong>engineering migration story</strong></a>.',
    },
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
