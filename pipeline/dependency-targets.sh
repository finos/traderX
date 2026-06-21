#!/usr/bin/env bash

traderx_dependency_targets_file() {
  local root="$1"
  echo "${TRADERX_DEPENDENCY_TARGETS_FILE:-${root}/catalog/dependency-version-targets.json}"
}

traderx_docker_image_tag() {
  local root="$1"
  local image_name="$2"
  local targets_file
  targets_file="$(traderx_dependency_targets_file "${root}")"

  [[ -f "${targets_file}" ]] || {
    echo "[fail] missing dependency targets file: ${targets_file}" >&2
    return 1
  }
  jq -er --arg image_name "${image_name}" '(.docker.images // {})[$image_name]' "${targets_file}"
}

traderx_docker_image_ref() {
  local root="$1"
  local image_name="$2"
  local tag
  tag="$(traderx_docker_image_tag "${root}" "${image_name}")"
  printf '%s:%s\n' "${image_name}" "${tag}"
}

traderx_normalize_yaml_image_tag() {
  local root="$1"
  local file="$2"
  local image_name="$3"
  local tag
  tag="$(traderx_docker_image_tag "${root}" "${image_name}")"

  [[ -f "${file}" ]] || return 0
  TRADERX_IMAGE_NAME="${image_name}" TRADERX_IMAGE_TAG="${tag}" perl -0pi -e '
    my $image = quotemeta($ENV{"TRADERX_IMAGE_NAME"});
    my $tag = $ENV{"TRADERX_IMAGE_TAG"};
    s/(image\s*:\s*["\x27]?$image:)[^" \x27\n]+(["\x27]?)/$1$tag$2/g;
  ' "${file}"
}
