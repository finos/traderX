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
        {to: '/docs/home', label: 'Docs', position: 'right'},
        {to: '/docs/traderspec', label: 'TraderSpec Ops', position: 'right'},
        {to: '/docs/traderspec/spec-kit-portal', label: 'Spec Kit', position: 'right'},
        {to: '/traderspec-specs/api', label: 'API Explorer', position: 'right'},
        {to: '/docs/roadmap', label: 'Roadmap', position: 'right'},
        {to: '/docs/team', label: 'Team', position: 'right'},
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
              to: '/docs/home',
            },
            {
              label: 'Roadmap',
              to: '/docs/roadmap',
            },
            {
              label: 'Team',
              to: '/docs/team',
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
          exclude: ['prompt-ideas/**'],
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
      '@docusaurus/plugin-content-docs',
      {
        id: 'traderspec',
        path: '../TraderSpec',
        routeBasePath: 'traderspec-specs',
        sidebarPath: require.resolve('./traderspec.sidebars.js'),
        include: [
          'speckit/**/*.md',
          'migration-todo.md',
          'migration-blog.md',
        ],
        exclude: ['codebase/target-generated/**', 'codebase/target-generated-specfirst/**'],
        editUrl: 'https://github.com/finos/traderX/edit/main/TraderSpec/',
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'traderspec-root-specs',
        path: '../specs',
        routeBasePath: 'traderspec-specs/specs',
        sidebarPath: require.resolve('./traderspec-root-specs.sidebars.js'),
        include: ['**/*.md'],
        editUrl: 'https://github.com/finos/traderX/edit/main/specs/',
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'traderspec-specify',
        path: '../.specify',
        routeBasePath: 'traderspec-specs/specify',
        sidebarPath: require.resolve('./traderspec-specify.sidebars.js'),
        include: ['memory/**/*.md'],
        editUrl: 'https://github.com/finos/traderX/edit/main/.specify/',
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'traderspec-api',
        path: '../api-docs',
        routeBasePath: 'traderspec-specs/api',
        sidebarPath: require.resolve('./traderspec-api.sidebars.js'),
        docItemComponent: '@theme/ApiItem',
        editUrl: 'https://github.com/finos/traderX/edit/main/api-docs/',
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
            outputDir: '../api-docs/account-service',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'people-service': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/people-service/openapi.yaml',
            outputDir: '../api-docs/people-service',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'position-service': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/position-service/openapi.yaml',
            outputDir: '../api-docs/position-service',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'reference-data': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/reference-data/openapi.yaml',
            outputDir: '../api-docs/reference-data',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'trade-processor': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/trade-processor/openapi.yaml',
            outputDir: '../api-docs/trade-processor',
            sidebarOptions: {
              groupPathsBy: 'tag',
            },
          },
          'trade-service': {
            specPath: '../specs/001-baseline-uncontainerized-parity/contracts/trade-service/openapi.yaml',
            outputDir: '../api-docs/trade-service',
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
