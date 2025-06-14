#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=./yb-thirdparty-common.sh
. "${BASH_SOURCE[0]%/*}/yb-thirdparty-common.sh"

# -------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------

show_usage() {
  cat <<-EOT
${0##*/} -- cleans third-party builds from various subdirectories of the thirdparty directory.
If invoked with --all, cleans all third-party builds.
Usage: ${0##*/} [<options>] [<dependency_names>]
Options:
  -h, --help
    Show usage
  --downloads, --download, -d
    Also clean downloads for the chosen dependencies. This could cause large dependencies to be
    re-downloaded, so should be used carefully.
  --all
    Clean all third-party dependency build artifacts. This is done using a "git clean" command.
EOT
}

realpath() {
  python -c "import os; import sys; print(os.path.realpath(sys.argv[1]))" "$@"
}

delete_dir() {
  if [[ $# -ne 1 ]]; then
    fatal "delete_dir expects exactly one arugment, got $#"
  fi
  local dir_path
  dir_path=$( realpath "$1" )
  if [[ -d $dir_path ]]; then
      log "DELETING directory '$dir_path'"
    ( set -x; rm -rf "$dir_path" )
  else
    log "'$dir_path' is not a directory or does not exist"
  fi
}

delete_file() {
  if [[ $# -ne 1 ]]; then
    fatal "delete_file expects exactly one arugment, got $#"
  fi
  local file_glob=$1
  local file_paths=( "$file_glob" )
  local file_path
  for file_path in "${file_paths[@]}"; do
    file_path=$( realpath "$file_path" )
    if [[ -f $file_path ]]; then
      log "DELETING file '$file_path'"
      ( set -x; rm -f "$file_path" )
    else
      log "'$file_path' is not a file or does not exist"
    fi
  done
}

# -------------------------------------------------------------------------------------------------
# Main script
# -------------------------------------------------------------------------------------------------

cd "$YB_THIRDPARTY_DIR"

dependency_names_to_clean=()
if [[ $# -eq 0 ]]; then
  show_usage >&2
  exit 1
fi

clean_all=false
delete_downloads=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_usage >&2
      exit 1
    ;;
    --all)
      clean_all=true
    ;;
    --downloads|--download|-d)
      delete_downloads=true
    ;;
    -*)
      fatal "Invalid option: $1"
    ;;
    *)
      dependency_names_to_clean+=( "$1" )
  esac
  shift
done

if "$clean_all"; then
  exclusions=(
    '*.sw?'
    venv*/
    .vscode/
    .mypy_cache/
    __pycache__/
    logs/
  )
  if ! "$delete_downloads"; then
    exclusions+=( download/ )
  fi
  git_clean_args=( -dxf )
  for exclusion in "${exclusions[@]}"; do
    git_clean_args+=( --exclude "$exclusion" )
  done
  # shellcheck disable=SC2086
  ( set -x; git clean "${git_clean_args[@]}" )
  exit
fi

for dep_name in "${dependency_names_to_clean[@]}"; do
  (
    set -x
    rm -rfv \
      "$YB_THIRDPARTY_DIR"/build/{common,uninstrumented,tsan}/{"$dep_name","$dep_name-"*,.build-stamp-"$dep_name"}
    rm -rfv "$YB_THIRDPARTY_DIR/src/${dep_name}-"*
  )

  for top_build_dir in "$YB_THIRDPARTY_DIR"/build/{common,uninstrumented,tsan}; do
    if [[ -d $top_build_dir ]]; then
      (
        cd "$top_build_dir"
        delete_file ".build-stamp-$dep_name"
      )
    else
      log "Directory '$top_build_dir' does not exist, ignoring"
    fi
  done
done
