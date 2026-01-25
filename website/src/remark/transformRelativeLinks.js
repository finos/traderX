/**
 * Remark plugin to transform relative links (e.g., ../account-service) 
 * to GitHub repository URLs when building Docusaurus.
 * 
 * This keeps links working on GitHub (relative) while making them 
 * absolute GitHub URLs in the Docusaurus site.
 */
const { visit } = require('unist-util-visit');

const plugin = (options) => {
  const { repoUrl, branch = 'main' } = options || {};
  
  return (tree) => {
    visit(tree, 'link', (node) => {
      const url = node.url;

      // Only transform relative links that go up to repo root (../) and not higher (../../)
      if (!url || !url.startsWith('../') || url.startsWith('../../')) return;

      // Split off hash and query to correctly detect extensions
      const [pathWithQuery, hashPart] = url.split('#');
      const [pathname, queryPart] = pathWithQuery.split('?');

      // Exclude markdown docs cross-links so Docusaurus handles them internally
      const isMarkdownDoc = pathname.endsWith('.md') || pathname.endsWith('.mdx');
      if (isMarkdownDoc) return;

      // Determine file vs directory to select /blob/ vs /tree/
      const lastSeg = pathname.split('/').pop();
      const hasExtension = /\.[A-Za-z0-9]+$/.test(lastSeg);
      const knownFilenames = new Set([
        'Tiltfile',
        'Dockerfile',
        'docker-compose.yml',
        'Makefile',
        'README',
        'README.md',
        'README.mdx',
      ]);
      const looksLikeFile = hasExtension || knownFilenames.has(lastSeg);

      // Extract the path after ../ and preserve any trailing slash
      const relativePath = pathname.replace(/^\..\//, '');

      if (repoUrl) {
        const base = looksLikeFile ? 'blob' : 'tree';
        // Reconstruct URL with preserved query/hash if present
        const q = queryPart ? `?${queryPart}` : '';
        const h = hashPart ? `#${hashPart}` : '';
        node.url = `${repoUrl}/${base}/${branch}/${relativePath}${q}${h}`;
      }
    });
  };
};

module.exports = plugin;
