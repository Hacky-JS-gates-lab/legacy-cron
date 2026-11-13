#!/usr/bin/env bash
# Lesson 5.1: try seven things with the job's GITHUB_TOKEN and print ALLOWED or DENIED for each.
# Runs inside token-demo.yml (env: GH_TOKEN, REPO, SHA, PR, RUN). Leaves a branch
# token-demo-<run>, a release/tag token-demo-<run> and a PR comment behind when the token
# can write; delete them after the demo (see README).
set -uo pipefail
try() {
  local what="$1"; shift
  if out=$("$@" 2>&1); then echo "ALLOWED  $what"
  else echo "DENIED   $what: $(tr -s '\n' ' ' <<<"$out" | cut -c1-240)"; fi
}
b="token-demo-$RUN"
try "comment on the PR"            gh pr comment "$PR" -R "$REPO" --body "token-demo run $RUN wrote this comment"
try "approve the PR"               gh pr review "$PR" -R "$REPO" --approve --body "approved by GITHUB_TOKEN"
try "create branch $b"             gh api "repos/$REPO/git/refs" -f ref="refs/heads/$b" -f sha="$SHA" --silent
try "create release and tag $b"    gh release create "$b" -R "$REPO" --target "$SHA" --title "$b" --notes "token-demo"
try "add a workflow file on $b"    gh api -X PUT "repos/$REPO/contents/.github/workflows/added-by-token.yml" \
  -f branch="$b" -f message="token-demo: add a workflow" \
  -f content="$(printf 'on: push\njobs: {}\n' | base64 -w0)" --silent
# The same workflow change through git, the way an agent with a checkout would push it.
push_workflow() {
  local auth; auth=$(printf 'x-access-token:%s' "$GH_TOKEN" | base64 -w0)
  mkdir -p .github/workflows && printf 'on: push\njobs: {}\n' > .github/workflows/added-by-token.yml
  git add .github/workflows/added-by-token.yml
  git -c user.name=token-demo -c user.email=token-demo@invalid commit -qm "token-demo: add a workflow"
  git -c http.https://github.com/.extraheader="AUTHORIZATION: basic $auth" push -q origin "HEAD:refs/heads/$b-git"
}
try "push a workflow file with git" push_workflow
try "move main to the PR head"     gh api -X PATCH "repos/$REPO/git/refs/heads/main" -f sha="$SHA" -F force=false --silent
