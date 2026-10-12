import React from 'react'
import Mermaid from '@theme-original/Mermaid'

// Mermaid diagrams render in the browser. Keep their source in the server HTML
// too, so static Markdown exports retain the architecture and flow definitions.
export default function MermaidWithSource(props) {
  return <>
    <Mermaid {...props} />
    <details>
      <summary>Diagram source</summary>
      <pre><code className="language-mermaid">{props.value}</code></pre>
    </details>
  </>
}
