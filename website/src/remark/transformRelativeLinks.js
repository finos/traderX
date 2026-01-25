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
      
      // Only transform relative links that go up to repo root (../)
      // and don't point to other markdown files
      if (url && url.startsWith('../') && !url.endsWith('.md') && !url.endsWith('.mdx')) {
        // Extract the path after ../
        const relativePath = url.replace(/^\.\.\//, '');
        
        // Build the GitHub URL
        if (repoUrl) {
          node.url = `${repoUrl}/tree/${branch}/${relativePath}`;
        }
      }
    });
  };
};

module.exports = plugin;
