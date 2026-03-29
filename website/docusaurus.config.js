// Docs at https://docusaurus.io/docs

const projectName = 'TraderX'
const projectSlug = 'traderX'
const copyrightOwner = 'FINOS - The Fintech Open Source Foundation'

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

module.exports = {
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
    repoUrl: `https://github.com/finos/${projectSlug}`,
  },
  scripts: ['https://buttons.github.io/buttons.js'],
  stylesheets: ['https://fonts.googleapis.com/css?family=Overpass:400,400i,700'],
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid', 'docusaurus-theme-openapi-docs'],
  themeConfig: {
    navbar: {
      title: `TraderX`,
      logo: {
        alt: 'TraderX Logo',
        src: 'img/favicon/favicon-traderX.ico',
      },
      items: [
        {to: '/docs/home', label: 'Overview', position: 'right'},
        {to: '/docs/spec-kit', label: 'Getting Started', position: 'right'},
        {to: '/specs', label: 'Specs', position: 'right'},
        {to: '/docs/spec-kit/state-docs', label: 'State Docs', position: 'right'},
        {to: '/docs/adr', label: 'ADRs', position: 'right'},
        {to: '/specify/memory/constitution', label: 'Constitution', position: 'right'},
        {to: '/docs/learning-paths', label: 'Learning Paths', position: 'right'},
        {to: '/api', label: 'API Explorer (001)', position: 'right'},
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
              label: 'Getting Started',
              to: '/docs/spec-kit',
            },
            {
              label: 'Learning Paths',
              to: '/docs/learning-paths',
            },
            {
              label: 'Specs',
              to: '/specs',
            },
            {
              label: 'Foundation',
              to: '/foundation',
            },
            {
              label: 'API Explorer (001)',
              to: '/api',
            },
            {
              label: 'Migration TODO',
              to: '/migration/migration-todo',
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
        excludeRoutes: ['/docs/guide/**', 'docs/guide/**'],
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'migration',
        path: '../migration-docs',
        routeBasePath: 'migration',
        sidebarPath: require.resolve('./migration.sidebars.js'),
        include: ['**/*.md'],
        editUrl: 'https://github.com/finos/traderX/edit/main/migration-docs/',
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
        id: 'foundation',
        path: '../foundation',
        routeBasePath: 'foundation',
        sidebarPath: require.resolve('./foundation.sidebars.js'),
        include: ['**/*.md'],
        editUrl: 'https://github.com/finos/traderX/edit/main/foundation/',
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
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'traderspec-api',
        path: '../generated/api-docs',
        routeBasePath: 'api',
        sidebarPath: require.resolve('./traderspec-api.sidebars.js'),
        docItemComponent: '@theme/ApiItem',
        editUrl: 'https://github.com/finos/traderX/edit/main/specs/001-baseline-uncontainerized-parity/contracts/',
      },
    ],
    [
      'docusaurus-plugin-openapi-docs',
      {
        id: 'traderspec-openapi',
        docsPluginId: 'traderspec-api',
        config: {
          'account-service': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/account-service/openapi.yaml',
            outputDir: '../generated/api-docs/account-service',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'people-service': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/people-service/openapi.yaml',
            outputDir: '../generated/api-docs/people-service',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'position-service': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/position-service/openapi.yaml',
            outputDir: '../generated/api-docs/position-service',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'reference-data': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/reference-data/openapi.yaml',
            outputDir: '../generated/api-docs/reference-data',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'trade-processor': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/trade-processor/openapi.yaml',
            outputDir: '../generated/api-docs/trade-processor',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'trade-service': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/trade-service/openapi.yaml',
            outputDir: '../generated/api-docs/trade-service',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
        },
      },
    ],
    pathBrowserPolyfillPlugin,
  ],
};
