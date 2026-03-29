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

function priorityFor(item) {
  if (item?.type === 'category') {
    const label = (item.label || '').toLowerCase()
    if (label === 'components') {
      return 0
    }
    if (label === 'system') {
      return 1
    }
  }
  return 2
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
  if (item?.type !== 'category') {
    return item
  }

  const label = item.label || ''
  const normalized = label.toLowerCase()
  let decoratedLabel = label

  if (depth === 0 && isStatePackLabel(label)) {
    decoratedLabel = `📦 ${label}`
  } else if (normalized === 'components') {
    decoratedLabel = '🧩 Components'
  } else if (normalized === 'system') {
    decoratedLabel = '💻 System'
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
