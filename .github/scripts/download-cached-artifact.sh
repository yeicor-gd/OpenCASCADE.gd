#!/usr/bin/env bash
# Download cached artifacts from previous CI runs.
#
# Tries recent workflow runs to find and restore cached build artifacts.
# Supports optional same-branch-first strategy with older-artifact cleanup.
#
# Usage:
#   download-cached-artifact.sh [OPTIONS] ARTIFACT_NAME DEST [ARTIFACT_NAME DEST ...]
#
# Options:
#   --same-branch-first    Try same-branch runs before trying all runs
#   --delete-older         Delete older same-branch artifacts after finding cache
#   --workflow NAME        Workflow name (default: $CI_WORKFLOW or $GITHUB_WORKFLOW)
#   --branch NAME          Branch name for same-branch strategy (default: $CI_REF or $GITHUB_REF_NAME)
#
# Env vars:
#   GH_TOKEN              GitHub token (required)
#   GH_REPO               GitHub repository in owner/repo format (required)
#   CI_WORKFLOW           Workflow name (fallback for --workflow)
#   CI_REF                Branch name (fallback for --branch)
#   GITHUB_REPOSITORY     Used for artifact deletion API calls
#
# Exit codes:
#   0  Success (check GITHUB_OUTPUT for cache-hit)
#   1  No arguments or invalid usage

set +e

SAME_BRANCH_FIRST=false
DELETE_OLDER=false
WORKFLOW="${CI_WORKFLOW:-${GITHUB_WORKFLOW:-}}"
BRANCH="${CI_REF:-${GITHUB_REF_NAME:-}}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --same-branch-first) SAME_BRANCH_FIRST=true; shift ;;
        --delete-older) DELETE_OLDER=true; shift ;;
        --workflow) WORKFLOW="$2"; shift 2 ;;
        --branch) BRANCH="$2"; shift 2 ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) break ;;
    esac
done

declare -a NAMES=()
declare -a DESTS=()
while [[ $# -gt 0 ]]; do
    NAMES+=("$1")
    DESTS+=("$2")
    shift 2
done

if [ ${#NAMES[@]} -eq 0 ]; then
    echo "Usage: $0 [OPTIONS] ARTIFACT_NAME DEST [ARTIFACT_NAME DEST ...]" >&2
    exit 1
fi

try_download() {
    local RUN="$1"
    local all_found=true
    for i in "${!NAMES[@]}"; do
        local TMP=$(mktemp -d)
        if gh run download "${RUN}" --name "${NAMES[$i]}" --dir "${TMP}" 2>/dev/null; then
            mkdir -p "${DESTS[$i]}"
            cp -r "${TMP}/." "${DESTS[$i]}/"
            echo "  ✓ ${NAMES[$i]}"
        else
            all_found=false
        fi
        rm -rf "${TMP}"
    done
    $all_found && return 0 || return 1
}

CACHE_HIT=false

# Strategy 1: Try same-branch runs first (faster, more relevant)
if [ "$SAME_BRANCH_FIRST" = true ] && [ -n "$BRANCH" ]; then
    echo "Trying same-branch runs (branch=${BRANCH})..."
    SAME_BRANCH_RUNS=$(gh run list --workflow="${WORKFLOW}" --branch="${BRANCH}" \
        --limit=25 --json databaseId -q '.[].databaseId' 2>/dev/null || echo "")

    deleting=false
    for RUN in ${SAME_BRANCH_RUNS}; do
        if [ "$deleting" = true ]; then
            if [ "$DELETE_OLDER" = true ]; then
                echo "Deleting older artifacts from run ${RUN}..."
                for i in "${!NAMES[@]}"; do
                    ART_ID=$(gh api \
                        "repos/${GITHUB_REPOSITORY}/actions/runs/${RUN}/artifacts" \
                        --jq ".artifacts[] | select(.name==\"${NAMES[$i]}\") | .id" \
                        2>/dev/null | head -1)
                    if [[ "$ART_ID" =~ ^[0-9]+$ ]]; then
                        gh api -X DELETE "repos/${GITHUB_REPOSITORY}/actions/artifacts/${ART_ID}" 2>/dev/null
                        echo "  Deleted ${NAMES[$i]} from run ${RUN}"
                    fi
                done
            fi
        elif try_download "${RUN}"; then
            echo "✓ Cached artifacts found in same-branch run ${RUN}"
            CACHE_HIT=true
            if [ "$DELETE_OLDER" = true ]; then
                echo "Deleting older same-branch run artifacts to save space..."
                deleting=true
            else
                break
            fi
        fi
    done
fi

# Strategy 2: Try all recent runs (broader search)
if [ "$CACHE_HIT" = false ]; then
    echo "Trying all recent runs..."
    ALL_RUNS=$(gh run list --workflow="${WORKFLOW}" --limit=25 \
        --json databaseId -q '.[].databaseId' 2>/dev/null || echo "")

    for RUN in ${ALL_RUNS}; do
        if try_download "${RUN}"; then
            echo "✓ Cached artifacts found in run ${RUN}"
            CACHE_HIT=true
            break
        fi
    done
fi

if [ "$CACHE_HIT" = false ]; then
    echo "::warning::No cached artifacts found, building fresh..."
fi

# Write output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "cache-hit=$CACHE_HIT" >> "$GITHUB_OUTPUT"
fi
