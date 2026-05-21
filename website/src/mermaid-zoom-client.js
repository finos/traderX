import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment'
import {initMermaidZoomControls} from './utils/mermaidZoomControls'

if (ExecutionEnvironment.canUseDOM) {
  window.__txMermaidZoomLoaded = true
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      initMermaidZoomControls()
    }, {once: true})
  } else {
    initMermaidZoomControls()
  }
}
