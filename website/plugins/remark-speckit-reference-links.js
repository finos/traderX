const FLOW_LINKS = {
  F1: '/specs/baseline-uncontainerized-parity/system/end-to-end-flows#f1-load-accounts-on-initial-ui-load',
  F2: '/specs/baseline-uncontainerized-parity/system/end-to-end-flows#f2-bootstrap-trade--position-blotters',
  F3: '/specs/baseline-uncontainerized-parity/system/end-to-end-flows#f3-submit-trade-ticket',
  F4: '/specs/baseline-uncontainerized-parity/system/end-to-end-flows#f4-process-trade-events',
  F5: '/specs/baseline-uncontainerized-parity/system/end-to-end-flows#f5-addupdate-account',
  F6: '/specs/baseline-uncontainerized-parity/system/end-to-end-flows#f6-addupdate-account-users',
}

function resolveReferenceLink(token) {
  const upper = token.toUpperCase()

  if (FLOW_LINKS[upper]) {
    return FLOW_LINKS[upper]
  }

  if (/^SYS-FR-\d{3}$/.test(upper) || /^SYS-NFR-\d{3}$/.test(upper)) {
    return '/specs/baseline-uncontainerized-parity/system/system-requirements'
  }

  if (/^US-\d{3}$/.test(upper)) {
    return '/specs/baseline-uncontainerized-parity/system/user-stories'
  }

  if (/^AC-\d{3}$/.test(upper)) {
    return '/specs/baseline-uncontainerized-parity/system/acceptance-criteria'
  }

  if (/^FR-\d{3}$/.test(upper) || /^NFR-\d{3}$/.test(upper) || /^SC-\d{3}$/.test(upper)) {
    return '/specs/baseline-uncontainerized-parity/spec'
  }

  if (/^T\d{3}[A-Z]?$/.test(upper)) {
    return '/specs/baseline-uncontainerized-parity/tasks'
  }

  return null
}

function visitNode(node, parent, index) {
  if (!node || typeof node !== 'object') {
    return
  }

  if (
    node.type === 'inlineCode' &&
    parent &&
    Array.isArray(parent.children) &&
    typeof index === 'number' &&
    parent.type !== 'link' &&
    parent.type !== 'linkReference'
  ) {
    const token = String(node.value || '').trim()
    const link = resolveReferenceLink(token)

    if (link) {
      parent.children[index] = {
        type: 'link',
        url: link,
        title: null,
        children: [{type: 'inlineCode', value: token}],
      }
      return
    }
  }

  if (Array.isArray(node.children)) {
    for (let i = 0; i < node.children.length; i += 1) {
      visitNode(node.children[i], node, i)
    }
  }
}

module.exports = function remarkSpecKitReferenceLinks() {
  return function transformer(tree) {
    visitNode(tree, null, null)
  }
}
