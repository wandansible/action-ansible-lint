#!/bin/bash

set -euo pipefail

PATH="/opt/venv/bin:${PATH}"

default_ansible_lint_args=""
default_validate_all_codebase="false"
default_branch="main"

ANSIBLE_LINT_ARGS="${ANSIBLE_LINT_ARGS:-$default_ansible_lint_args}"
VALIDATE_ALL_CODEBASE="${VALIDATE_ALL_CODEBASE:-$default_validate_all_codebase}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-$default_branch}"

lint_cmd="ansible-lint"

if [ -n "${ANSIBLE_LINT_ARGS}" ]; then
    lint_cmd="${lint_cmd} ${ANSIBLE_LINT_ARGS}"
fi

if ! lint_cmd_check="$(${lint_cmd} --version 2>&1)"; then
    echo "Invalid arguments provided for lint command: ${lint_cmd}"
    echo "Command output:"
    echo "------"
    echo "${lint_cmd_check}"
    echo "------"
    echo ""
    echo "Invalid ansible-lint arguments provided, exiting" >&2
    exit 3
fi

if [ "${VALIDATE_ALL_CODEBASE}" = "true" ]; then
    echo "Linting entire code base"
    echo ""
    echo "Running lint command: ${lint_cmd}"
    echo "Command output:"
    echo "------"

    lint_status=0
    ${lint_cmd} || lint_status=$?

    echo "------"
    if [ "${lint_status}" -ne 0 ]; then
        echo ""
        echo "Exiting with ansible linting errors"
    fi

    exit "${lint_status}"
fi

echo "Linting new or changed files"

if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
    GITHUB_SHA="$(jq -r .pull_request.head.sha < "${GITHUB_EVENT_PATH}")"
fi

git checkout --quiet "${DEFAULT_BRANCH}"
git checkout --quiet "${GITHUB_SHA}"

if [ "${GITHUB_EVENT_NAME}" = "push" ]; then
    all_files="$(git diff-tree --no-commit-id --name-only -r "${GITHUB_SHA}")"

    if [ -z "${all_files}" ]; then
        all_files="$(git diff --name-only --diff-filter=d "${DEFAULT_BRANCH}...${GITHUB_SHA}")"
    fi
else
    all_files="$(git diff --name-only --diff-filter=d "${DEFAULT_BRANCH}...${GITHUB_SHA}")"
fi

echo ""
echo "Generated file list:"
check_files=""
for file in ${all_files}; do
    if [ -f "${file}" ]; then
        echo "  * ${file}"
        check_files="${check_files} ${file}"
    fi
done

if [ -z "${check_files}" ]; then
    echo "No files to check"
    exit 0
fi

echo ""
echo "Running lint command: ${lint_cmd}"
echo "Command output:"
echo "------"

lint_errors=0
lint_warnings=0
while read -r line; do
    line="$(echo "${line}" | xargs)"

    if echo "${line}" | grep -E "^::(error|warning) .*file=([^,]+).+::" > /dev/null; then
        annotation_severity="$(echo "${line#::*}" | cut -d ' ' -f 1)"
        annotation_file="$(echo "${line}" | grep -oE "file=([^,]+)" | head -n 1 | cut -d '=' -f 2-)"

        for file in ${check_files}; do
            if [ "${annotation_file}" = "${file}" ]; then
                echo "${line}"

                if [ "${annotation_severity}" = "error" ]; then
                    lint_errors=$((lint_errors + 1))
                else
                    lint_warnings=$((lint_warnings + 1))
                fi
            fi
        done
    else
        echo "${line}"
    fi
done < <(${lint_cmd})

echo "------"
echo ""
echo "Total errors: ${lint_errors}"
echo "Total warnings: ${lint_warnings}"

if [ "${lint_errors}" -gt 0 ]; then
    echo "Exiting with ansible linting errors"
    exit 2
fi
