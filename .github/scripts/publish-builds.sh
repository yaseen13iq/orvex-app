#!/usr/bin/env bash
# ينشر الملفات الموجودة في مجلد معيّن إلى فرع builds بدون ما يمسح ملفات غيره
# الاستعمال: publish-builds.sh <folder> "<commit message>"
set -euo pipefail
SRC="$1"; MSG="$2"
cd "$GITHUB_WORKSPACE"
git config user.name "orvex-bot"
git config user.email "actions@users.noreply.github.com"
for attempt in 1 2 3 4 5 6; do
  rm -rf /tmp/pub
  git worktree prune
  if git fetch -q --depth=1 origin builds 2>/dev/null; then
    git worktree add -q --detach /tmp/pub FETCH_HEAD
  else
    git worktree add -q --detach /tmp/pub HEAD
    (cd /tmp/pub && git checkout -q --orphan builds-new && git rm -rfq . && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +)
  fi
  for d in "$SRC"/*/; do [ -d "$d" ] && rm -rf "/tmp/pub/$(basename "$d")"; done
  cp -rf "$SRC"/. /tmp/pub/
  if (cd /tmp/pub && git add -A && { git commit -qm "$MSG" || true; } && git push -q origin HEAD:refs/heads/builds); then
    echo "published to builds (attempt $attempt)"; exit 0
  fi
  sleep $((attempt * 5))
done
echo "could not publish"; exit 1
