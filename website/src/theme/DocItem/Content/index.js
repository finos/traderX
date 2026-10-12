import React from 'react'
import Head from '@docusaurus/Head'
import useBaseUrl from '@docusaurus/useBaseUrl'
import {useDoc} from '@docusaurus/plugin-content-docs/client'
import Content from '@theme-original/DocItem/Content'

export default function DocContent(props) {
  const {metadata} = useDoc()
  const markdownUrl = `${metadata.permalink.replace(/\/$/, '')}.md`
  const indexUrl = useBaseUrl('/llms.txt')
  return <>
    <Head><link rel="alternate" type="text/markdown" href={markdownUrl} /></Head>
    <p className="docs-discovery-links">
      <a href={markdownUrl}>View Markdown</a>{' · '}
      <a href={indexUrl}>Documentation index (llms.txt)</a>
    </p>
    <Content {...props} />
  </>
}
