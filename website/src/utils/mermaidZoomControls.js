const STEP = 0.2
const MIN_SCALE = 0.6
const MAX_SCALE = 2.4
const MAX_INITIAL_SCALE = 1.2
const DEFAULT_MAX_CANVAS_HEIGHT = 600
const CONTROL_BAR_COMPENSATION = 44
const SMALL_DIAGRAM_THRESHOLD = 150

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value))
}

function applyScale(svg, value) {
  svg.style.transformOrigin = 'top left'
  svg.style.transform = `scale(${value})`
}

function canvasHeightForPath() {
  return DEFAULT_MAX_CANVAS_HEIGHT
}

function initialScaleFor(svg, targetCanvasHeight) {
  let contentHeight = svg.getBoundingClientRect().height || 0
  try {
    if (!contentHeight) {
      contentHeight = svg.getBBox().height || 0
    }
    if (!contentHeight) {
      contentHeight = svg.viewBox?.baseVal?.height || 0
    }
    if (!contentHeight) {
      contentHeight = svg.getBoundingClientRect().height || 0
    }
  } catch (_) {
    contentHeight = svg.getBoundingClientRect().height || 0
  }

  if (!contentHeight || contentHeight <= 0) {
    return 1
  }
  const fitScale = targetCanvasHeight / contentHeight
  return clamp(Math.min(fitScale, MAX_INITIAL_SCALE), MIN_SCALE, MAX_SCALE)
}

function makeButton(label, title, onClick) {
  const button = document.createElement('button')
  button.type = 'button'
  button.className = 'tx-mermaid-zoom-btn'
  button.setAttribute('aria-label', title)
  button.title = title
  button.textContent = label
  button.addEventListener('click', onClick)
  return button
}

function enhanceDiagram(container) {
  if (!container || container.dataset.txZoomReady === 'true') {
    return
  }

  const svg = container.querySelector('svg')
  if (!svg) {
    return
  }

  const naturalHeight = svg.getBoundingClientRect().height || 0
  if (naturalHeight > 0 && naturalHeight <= SMALL_DIAGRAM_THRESHOLD) {
    container.dataset.txZoomReady = 'true'
    return
  }

  container.dataset.txZoomReady = 'true'

  const targetCanvasHeight = canvasHeightForPath()
  const shell = document.createElement('div')
  shell.className = 'tx-mermaid-zoom-shell'

  const controls = document.createElement('div')
  controls.className = 'tx-mermaid-zoom-controls'

  const viewport = document.createElement('div')
  viewport.className = 'tx-mermaid-zoom-viewport'
  viewport.style.maxHeight = `${targetCanvasHeight}px`
  const canvas = document.createElement('div')
  canvas.className = 'tx-mermaid-zoom-canvas'
  viewport.appendChild(canvas)

  const defaultScale = initialScaleFor(svg, targetCanvasHeight + CONTROL_BAR_COMPENSATION)
  let scale = defaultScale
  applyScale(svg, scale)

  const backdrop = document.createElement('div')
  backdrop.className = 'tx-mermaid-modal-backdrop'
  let modalOpen = false
  let preModalScale = defaultScale

  function syncFullButton() {
    if (modalOpen) {
      fullscreen.textContent = 'Exit'
      fullscreen.title = 'Exit fullscreen view'
    } else {
      fullscreen.textContent = 'Full'
      fullscreen.title = 'Open fullscreen view'
    }
  }

  function setModal(open) {
    if (open === modalOpen) {
      return
    }
    modalOpen = open

    if (modalOpen) {
      const existing = document.querySelector('.tx-mermaid-zoom-shell--modal')
      if (existing && existing !== shell) {
        existing.dispatchEvent(new CustomEvent('tx-close-modal'))
      }

      if (!backdrop.isConnected) {
        document.body.appendChild(backdrop)
      }
      requestAnimationFrame(() => backdrop.classList.add('is-visible'))
      shell.classList.add('tx-mermaid-zoom-shell--modal')
      document.body.classList.add('tx-mermaid-modal-open')
      viewport.style.maxHeight = 'none'
      preModalScale = scale
      requestAnimationFrame(() => {
        if (!modalOpen) {
          return
        }
        const modalViewportHeight = Math.max(viewport.clientHeight, 360)
        const currentHeight = svg.getBoundingClientRect().height / Math.max(scale, 0.0001)
        if (currentHeight > 0) {
          const modalFit = Math.min(MAX_SCALE, modalViewportHeight / currentHeight)
          scale = clamp(Math.max(scale, modalFit), MIN_SCALE, MAX_SCALE)
          applyScale(svg, scale)
        }
      })
    } else {
      shell.classList.remove('tx-mermaid-zoom-shell--modal')
      document.body.classList.remove('tx-mermaid-modal-open')
      viewport.style.maxHeight = `${targetCanvasHeight}px`
      scale = preModalScale
      applyScale(svg, scale)
      backdrop.classList.remove('is-visible')
      window.setTimeout(() => {
        if (!modalOpen && backdrop.parentElement) {
          backdrop.parentElement.removeChild(backdrop)
        }
      }, 120)
    }
    syncFullButton()
  }

  const zoomOut = makeButton('−', 'Zoom out', () => {
    scale = clamp(scale - STEP, MIN_SCALE, MAX_SCALE)
    applyScale(svg, scale)
  })
  const zoomIn = makeButton('+', 'Zoom in', () => {
    scale = clamp(scale + STEP, MIN_SCALE, MAX_SCALE)
    applyScale(svg, scale)
  })
  const reset = makeButton('100%', 'Reset zoom', () => {
    scale = defaultScale
    applyScale(svg, scale)
  })
  const fullscreen = makeButton('Full', 'Open fullscreen view', () => {
    setModal(!modalOpen)
  })
  backdrop.addEventListener('click', () => setModal(false))
  shell.addEventListener('tx-close-modal', () => setModal(false))
  window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && modalOpen) {
      setModal(false)
    }
  })

  controls.appendChild(zoomOut)
  controls.appendChild(reset)
  controls.appendChild(zoomIn)
  controls.appendChild(fullscreen)
  syncFullButton()

  const parent = container.parentElement
  if (!parent) {
    return
  }

  parent.insertBefore(shell, container)
  shell.appendChild(controls)
  shell.appendChild(viewport)
  canvas.appendChild(container)
}

function enhanceAllMermaid() {
  const diagrams = document.querySelectorAll('.theme-mermaid, .mermaid, .docusaurus-mermaid-container')
  diagrams.forEach((container) => {
    if (container.querySelector('svg')) {
      enhanceDiagram(container)
      return
    }

    const observer = new MutationObserver(() => {
      if (!container.querySelector('svg')) {
        return
      }
      observer.disconnect()
      enhanceDiagram(container)
    })
    observer.observe(container, {childList: true, subtree: true})
    setTimeout(() => observer.disconnect(), 10000)
  })
}

export function initMermaidZoomControls() {
  const tick = () => enhanceAllMermaid()
  tick()
  const interval = window.setInterval(tick, 600)
  return () => window.clearInterval(interval)
}
