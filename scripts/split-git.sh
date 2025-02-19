#!/bin/bash

set -eu
set -o pipefail

TARGET=$1

ARCHIVE_MAX=$(
    gh api --paginate /orgs/vulsio/packages/container/vuls-data-db/versions |
    (
      jq -r '.[] | select(.metadata.container.tags | length > 0) | .metadata.container.tags[0]';
      echo "${TARGET}-archive-0"
    ) |
    grep -v ${TARGET}'$' |
    grep -v -- '-backup' |
    grep ${TARGET} |
    sed -e 's/'${TARGET}'-archive-//' |
    sort -rn |
    head -1
)

ARCHIVE_SUFFIX=archive-$(( ${ARCHIVE_MAX} + 1 ))
echo "ARCHIVE_SUFFIX=${ARCHIVE_SUFFIX}" 1>&2

mkdir latest/
cd latest/
tar -xf ../${TARGET}.tar.zst

mv ${TARGET} ${TARGET}.tmp
echo "Create the latest repository..." 1>&2
git clone --depth 1 --no-single-branch  --no-checkout --branch main file://${PWD}/${TARGET}.tmp ${TARGET}
rm -rf ${TARGET}.tmp
tar --remove-files -acf ${TARGET}.tar.zst ${TARGET}

echo ${ARCHIVE_SUFFIX}
