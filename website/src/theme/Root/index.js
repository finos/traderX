import React, {useEffect} from 'react'
import Root from '@theme-original/Root'
import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment'
import {initMermaidZoomControls} from '../../utils/mermaidZoomControls'

export default function RootWrapper(props) {
  useEffect(() => {
    if (!ExecutionEnvironment.canUseDOM) {
      return undefined
    }
    return initMermaidZoomControls()
  }, [])

  return <Root {...props} />
}
