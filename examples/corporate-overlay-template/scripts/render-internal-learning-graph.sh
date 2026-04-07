#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_GRAPH="${ROOT}/corporate/catalog/sanctioned-learning-graph.yaml"
TARGET_DOC="${ROOT}/corporate/docs/internal-learning-graph.generated.md"

if [[ ! -f "${SOURCE_GRAPH}" ]]; then
  echo "[fail] missing sanctioned graph source: ${SOURCE_GRAPH}"
  exit 1
fi

{
  echo "# Internal Sanctioned Learning Graph (Generated)"
  echo
  echo "Source: \`corporate/catalog/sanctioned-learning-graph.yaml\`"
  echo
  echo "## Sanctioned States"
  awk '
    $1=="-" && $2=="id:" {print "- `" $3 "`"}
  ' "${SOURCE_GRAPH}"
  echo
  echo "## Mermaid"
  echo
  echo '```mermaid'
  echo 'flowchart LR'
  awk '
    function node_name(id,    tmp) {
      tmp=id
      gsub(/-/, "_", tmp)
      return "N_" tmp
    }

    $1=="-" && $2=="id:" {
      id=$3
      print "  " node_name(id) "[\"" id "\"]"
    }

    $1=="-" && $2=="from:" {from=$3}
    $1=="to:" {
      to=$2
      gsub(/"/, "", to)
      print "  " node_name(from) " --> " node_name(to)
    }
  ' "${SOURCE_GRAPH}"
  echo '```'
} > "${TARGET_DOC}"

echo "[ok] wrote ${TARGET_DOC}"
