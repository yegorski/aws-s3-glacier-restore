#!/bin/bash

set -eo pipefail

restore() {
    declare bucket="${1}"
    declare objects_file="${2}"

    while read line; do
        echo "${line}"
        aws-okta exec root -- s3cmd restore --restore-days=30 --restore-priority=expedited "s3://${bucket}/${line}"
    done < $objects_file
}

copy() {
    declare bucket="${1}"
    declare objects_file="${2}"

    while read line; do
        echo "${line}"
        aws-okta exec root -- aws s3 cp "s3://${bucket}/${line}" "s3://${bucket}/${line}"  --storage-class=STANDARD --force-glacier-transfer
    done < $objects_file
}

"$@"
