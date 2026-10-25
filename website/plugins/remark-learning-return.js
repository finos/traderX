const {states} = require('../../catalog/state-catalog.json');

// All Markdown in a catalog state, including deeply nested system/contract pages,
// gets the same return path. No generated source files are edited for this banner.
module.exports = function learningReturn() {
  return (tree, file) => {
    const filename = String(file.path || file.history?.[0] || '').replaceAll('\\', '/');
    const state = states.find(s => filename.includes(`/${s.featurePack}/`));
    if (!state) return;
    const paragraph = {
      type: 'paragraph', children: [
        {type: 'link', url: `/docs/learning/state-${state.id}`, children: [{type: 'text', value: `Learning Guide — ${state.title}`}]},
        {type: 'text', value: ': purpose, walkthrough, and related learning states.'},
      ],
    };
    const heading = tree.children.findIndex(n => n.type === 'heading' && n.depth === 1);
    tree.children.splice(heading >= 0 ? heading + 1 : 0, 0, paragraph);
  };
};
