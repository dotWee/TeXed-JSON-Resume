#!/bin/bash
# git-changelog.sh
# Generate a changelog from commit messages between two git tags.
#
# Usage:
#   ./scripts/git-changelog.sh [FROM_REF]
#
# If FROM_REF is given (e.g. a tag like "v1.0.0"), the changelog covers
# commits from FROM_REF (exclusive) to HEAD.
#
# If FROM_REF is omitted, the script auto-detects the latest tag reachable
# from HEAD and uses that as the starting point.
#
# If no tags exist at all, all commits are included.
#
# Output is written to stdout as a bullet list of commit subjects.

set -euo pipefail

FROM_REF="${1:-}"

if [ -z "$FROM_REF" ]; then
  FROM_REF=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
fi

if [ -n "$FROM_REF" ]; then
  git log --pretty=format:"- %s" "${FROM_REF}..HEAD"
else
  git log --pretty=format:"- %s"
fi
