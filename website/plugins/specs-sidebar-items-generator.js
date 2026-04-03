function labelFor(item) {
  if (!item) {
    return ''
  }
  if (typeof item.label === 'string' && item.label.length > 0) {
    return item.label
  }
  if (typeof item.id === 'string') {
    return item.id
  }
  if (typeof item.href === 'string') {
    return item.href
  }
  return ''
}

function normalizeLabel(label) {
  return (label || '')
    .toLowerCase()
    .replace(/^[^a-z0-9]+/i, '')
    .trim()
}

function docSlug(item) {
  if (item?.type !== 'doc' || typeof item.id !== 'string') {
    return ''
  }
  const parts = item.id.split('/')
  return parts[parts.length - 1]?.toLowerCase() ?? ''
}

function priorityFor(item) {
  if (item?.type === 'doc') {
    const slug = docSlug(item)
    const order = {
      readme: 0,
      spec: 1,
      plan: 2,
      tasks: 3,
      research: 4,
      'data-model': 5,
      quickstart: 6,
      'fidelity-profile': 7,
    }
    if (Object.prototype.hasOwnProperty.call(order, slug)) {
      return order[slug]
    }
    return 8
  }

  if (item?.type === 'category') {
    const label = normalizeLabel(item.label || '')
    if (label === 'components') {
      return 20
    }
    if (label === 'system') {
      return 21
    }
    if (label === 'contracts') {
      return 22
    }
    if (label === 'requirements') {
      return 23
    }
    if (label === 'conformance') {
      return 24
    }
    if (label === 'tests') {
      return 25
    }
    if (label === 'generation') {
      return 26
    }
  }

  return 30
}

function sortItems(items) {
  return [...items].sort((left, right) => {
    const pLeft = priorityFor(left)
    const pRight = priorityFor(right)
    if (pLeft !== pRight) {
      return pLeft - pRight
    }
    return labelFor(left).localeCompare(labelFor(right), undefined, {
      numeric: true,
      sensitivity: 'base',
    })
  })
}

function isStatePackLabel(label) {
  return /^[0-9]{3}(\b|[-\s])/.test(label) || /^feature pack\s+[0-9]{3}\b/i.test(label)
}

function transformItem(item, depth = 0) {
  if (item?.type === 'doc') {
    const slug = docSlug(item)
    const docDecorations = {
      readme: '📘 Overview',
      spec: '📜 Specification',
      plan: '🗺️ Implementation Plan',
      tasks: '✅ Tasks',
      research: '🔎 Research',
      'data-model': '🧱 Data Model',
      quickstart: '🚀 Quickstart',
      'fidelity-profile': '🎯 Fidelity Profile',
    }
    if (docDecorations[slug]) {
      return {
        ...item,
        label: docDecorations[slug],
      }
    }
    return item
  }

  if (item?.type !== 'category') {
    return item
  }

  const label = item.label || ''
  const normalized = normalizeLabel(label)
  let decoratedLabel = label

  const categoryDecorations = {
    components: '🧩 Components',
    system: '💻 System',
    contracts: '📜 Contracts',
    conformance: '✅ Conformance',
    generation: '⚙️ Generation',
    requirements: '🧾 Requirements',
    tests: '🧪 Tests',
  }

  if (depth === 0 && isStatePackLabel(label)) {
    decoratedLabel = `📦 ${label}`
  } else if (categoryDecorations[normalized]) {
    decoratedLabel = categoryDecorations[normalized]
  }

  const children = Array.isArray(item.items)
    ? item.items.map((child) => transformItem(child, depth + 1))
    : []

  return {
    ...item,
    label: decoratedLabel,
    items: sortItems(children),
  }
}

module.exports = async function specsSidebarItemsGenerator({
  defaultSidebarItemsGenerator,
  ...args
}) {
  const generated = await defaultSidebarItemsGenerator(args)
  const transformed = generated.map((item) => transformItem(item, 0))
  return sortItems(transformed)
}
