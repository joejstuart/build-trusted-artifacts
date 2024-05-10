#!/bin/bash
# Creates specified trusted artifacts
set -o errexit
set -o nounset
set -o pipefail

tar_opts=-czf
if [[ -v DEBUG ]]; then
  tar_opts=-cvzf
  set -o xtrace
fi

# contains {result path}={artifact source path} pairs
artifact_pairs=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --store)
        store="$2"
        shift
        shift
        ;;
        --results)
        result_path="$2"
        shift
        shift
        ;;
        -*)
        echo "Unknown option $1"
        exit 1
        ;;
        *)
        artifact_pairs+=("$1")
        shift
        ;;
    esac
done

# The `--store`` was not provided, use first available workspace.
if [ -z "${store}" ]; then
    workspaces=(/workspace/*)
    for w in "${workspaces[@]}"; do
        if [ -d "${w}" ]; then
            store="${w}"
            echo "Using ${store} for artifact storage, provide --store <path> to customize"
            break
        fi
    done
fi

if [ ! -d "${store}" ]; then
    echo "Unable to use artifact store: ${store}, the provided path is either missing or not a directory"
    exit 1
fi

for artifact_pair in "${artifact_pairs[@]}"; do
    result_path="${artifact_pair/=*}"
    path="${artifact_pair/*=}"

    archive="$(mktemp).tar.gz"

    log "creating tar archive %s with files from %s" "${archive}" "${path}"

    if [ ! -r "${path}" ]; then
        # non-existent paths result in empty archives
        tar "${tar_opts}" "${archive}" --files-from /dev/null
    elif [ -d "${path}" ]; then
        # archive the whole directory
        tar "${tar_opts}" "${archive}" -C "${path}" .
    else
        # archive a single file
        tar "${tar_opts}" "${archive}" -C "${path%/*}" "${path##*/}"
    fi

    sha256sum_output="$(sha256sum "${archive}")"
    digest="${sha256sum_output/ */}"
    artifact="${store}/sha256-${digest}.tar.gz"
    mv "${archive}" "${artifact}"
    echo -n "file:sha256-${digest}" > "${result_path}"

    echo Created artifact from "${path} (sha256:${digest})"
done
