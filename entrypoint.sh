#!/bin/bash

set -eux

if "$INPUT_DISABLE_GLOBBING"; then
    set -o noglob;
fi

_main() {
    echo "GIVEN: ib=$INPUT_BRANCH or ghw=$GITHUB_WORKSPACE or ghr=$GITHUB_HEAD_REF";
    export INPUT_BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF}}";
    if [ -z "$INPUT_BRANCH" ]; then exit 666;fi
    echo "INPUT_BRANCH value: ${INPUT_BRANCH}";

    _switch_to_repository

    if _git_is_dirty || "$INPUT_SKIP_DIRTY_CHECK"; then

        echo "::set-output name=changes_detected::true";

        _switch_to_branch

        _add_files

        _local_commit

        _tag_commit

        _push_to_github
    else

        echo "::set-output name=changes_detected::false";

        echo "Working tree clean. Nothing to commit.";
    fi
}


_switch_to_repository() {
    echo "🥴"
    cd "${GITHUB_WORKSPACE}";
}

_git_is_dirty() {
    echo "INPUT_STATUS_OPTIONS: ${INPUT_STATUS_OPTIONS}";
    echo "::debug::Apply status options ${INPUT_STATUS_OPTIONS}";

    # shellcheck disable=SC2086
    [ -n "$(git status -s $INPUT_STATUS_OPTIONS -- $INPUT_FILE_PATTERN)" ]
}

_switch_to_branch() {

    # Fetch remote to make sure that repo can be switched to the right branch.

    if "$INPUT_SKIP_FETCH"; then
        echo "::debug::git-fetch has not been executed";
    else
        git fetch --depth=1;
    fi

    # Switch to branch from current Workflow run
    # shellcheck disable=SC2086
    cd "${GITHUB_WORKSPACE}"
    git checkout "${INPUT_BRANCH}";
}

_add_files() {
    echo "INPUT_ADD_OPTIONS: ${INPUT_ADD_OPTIONS}";
    echo "::debug::Apply add options ${INPUT_ADD_OPTIONS}";

    echo "INPUT_FILE_PATTERN: ${INPUT_FILE_PATTERN}";

    # shellcheck disable=SC2086
    git add ${INPUT_ADD_OPTIONS} ${INPUT_FILE_PATTERN};
}

_local_commit() {
    echo "INPUT_COMMIT_OPTIONS: ${INPUT_COMMIT_OPTIONS}";
    echo "::debug::Apply commit options ${INPUT_COMMIT_OPTIONS}";

    # shellcheck disable=SC2206
    INPUT_COMMIT_OPTIONS_ARRAY=( $INPUT_COMMIT_OPTIONS );

    echo "INPUT_COMMIT_USER_NAME: ${INPUT_COMMIT_USER_NAME}";
    echo "INPUT_COMMIT_USER_EMAIL: ${INPUT_COMMIT_USER_EMAIL}";
    echo "INPUT_COMMIT_MESSAGE: ${INPUT_COMMIT_MESSAGE}";
    echo "INPUT_COMMIT_AUTHOR: ${INPUT_COMMIT_AUTHOR}";

    git -c user.name="$INPUT_COMMIT_USER_NAME" -c user.email="$INPUT_COMMIT_USER_EMAIL" \
        commit -m "$INPUT_COMMIT_MESSAGE" \
        --author="$INPUT_COMMIT_AUTHOR" \
        ${INPUT_COMMIT_OPTIONS:+"${INPUT_COMMIT_OPTIONS_ARRAY[@]}"};

    echo "::set-output name=commit_hash::$(git rev-parse HEAD)";
}

_tag_commit() {
    echo "INPUT_TAGGING_MESSAGE: ${INPUT_TAGGING_MESSAGE}"

    if [ -n "$INPUT_TAGGING_MESSAGE" ]
    then
        echo "::debug::Create tag $INPUT_TAGGING_MESSAGE";
        git -c user.name="$INPUT_COMMIT_USER_NAME" -c user.email="$INPUT_COMMIT_USER_EMAIL" tag -a "$INPUT_TAGGING_MESSAGE" -m "$INPUT_TAGGING_MESSAGE";
    else
        echo "No tagging message supplied. No tag will be added.";
    fi
}

_push_to_github() {

    echo "INPUT_PUSH_OPTIONS: ${INPUT_PUSH_OPTIONS}";
    echo "::debug::Apply push options ${INPUT_PUSH_OPTIONS}";

    # shellcheck disable=SC2206
    INPUT_PUSH_OPTIONS_ARRAY=( $INPUT_PUSH_OPTIONS );

    if [ -z "$INPUT_BRANCH" ]
    then
        # Only add `--tags` option, if `$INPUT_TAGGING_MESSAGE` is set
        if [ -n "$INPUT_TAGGING_MESSAGE" ]
        then
            echo "::debug::git push origin --tags";
            git push origin --follow-tags --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
        else
            echo "::debug::git push origin";
            git push origin ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
        fi

    else
        echo "::debug::Push commit to remote branch $INPUT_BRANCH";
        git push --set-upstream origin "HEAD:$INPUT_BRANCH" --follow-tags --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
    fi
}

_main
