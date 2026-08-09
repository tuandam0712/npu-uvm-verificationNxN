#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
profile="${1:-quick}"

case "$profile" in
    quick)
        config="formal/sarr/sarr.sby"
        task_timeout=120
        ;;
    8x8)
        config="formal/sarr/sarr_8x8.sby"
        task_timeout=600
        ;;
    *)
        echo "usage: $0 [quick|8x8]" >&2
        exit 2
        ;;
esac

cd "$repo_root"
for task in reset clear operand valid mac_hold cover; do
    echo "== SARR formal: profile=$profile task=$task =="
    timeout --signal=INT --kill-after=5s "${task_timeout}s" \
        sby -f "$config" "$task"
done

echo "== SARR formal profile '$profile': PASS =="
