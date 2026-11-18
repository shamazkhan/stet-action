#!/usr/bin/env bash
# Runs `stet guard`, `stet check` and (optionally) `stet pr lint` in CI and writes a job summary. Inputs arrive as STET_* env vars.
set -uo pipefail
STET="npx -y stet-cli@${STET_VERSION:-latest}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
OUTPUT="${GITHUB_OUTPUT:-/dev/null}"
export NO_COLOR=1

if [ ! -d .stet ]; then
  echo "::warning title=Stet not set up::No .stet/ folder in $(pwd). Run 'npx stet-cli init' and commit .stet/, AGENTS.md and CLAUDE.md."
  { echo "### Stet"; echo "No \`.stet/\` folder found. Run \`npx stet-cli init\` and commit it."; } >> "$SUMMARY"
  echo "result=pass" >> "$OUTPUT"; exit 0
fi

# Work out what to compare against: explicit input, the PR's merge base, or the previous commit on push.
BASE="${STET_BASE:-}"
if [ -z "$BASE" ]; then
  if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then git fetch --quiet --unshallow --no-tags origin 2>/dev/null || true; fi
  if [ -n "${GITHUB_BASE_REF:-}" ]; then
    git fetch --quiet --no-tags origin "$GITHUB_BASE_REF" 2>/dev/null || true
    BASE="$(git merge-base HEAD "origin/$GITHUB_BASE_REF" 2>/dev/null || echo "origin/$GITHUB_BASE_REF")"
  elif [ -n "${STET_PUSH_BEFORE:-}" ] && ! [[ "$STET_PUSH_BEFORE" =~ ^0+$ ]] && git cat-file -e "$STET_PUSH_BEFORE^{commit}" 2>/dev/null; then
    BASE="$STET_PUSH_BEFORE"
  else
    BASE="HEAD~1"
  fi
fi

echo "### Stet: guardrails for AI coding agents" >> "$SUMMARY"
guard_rc=0; check_rc=0

if [ "${STET_GUARD:-true}" = "true" ]; then
  args=(guard --base "$BASE"); [ "${STET_WARN:-false}" = "true" ] && args+=(--warn)
  echo "::group::stet guard (compared with ${BASE:0:12})"
  g_out="$($STET "${args[@]}" 2>&1)"; guard_rc=$?
  echo "$g_out"; echo "::endgroup::"
  { echo "#### Guard"; echo '```'; echo "$g_out"; echo '```'; } >> "$SUMMARY"
  if [ $guard_rc -ne 0 ]; then echo "::error title=Stet guard::Files changed outside the task scope or in protected paths. See the job summary."; fi
fi

if [ "${STET_CHECK:-true}" = "true" ]; then
  args=(check); [ -n "${STET_ONLY:-}" ] && args+=(--only "$STET_ONLY")
  echo "::group::stet check"
  c_out="$($STET "${args[@]}" 2>&1)"; check_rc=$?
  echo "$c_out"; echo "::endgroup::"
  { echo "#### Locked behaviours"; echo '```'; echo "$c_out"; echo '```'; } >> "$SUMMARY"
  if [ $check_rc -ne 0 ]; then echo "::error title=Stet check::A locked behaviour is failing. Fix the change, not the check."; fi
fi

format_rc=0
if [ "${STET_PR_FORMAT:-false}" = "true" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -n "${GITHUB_BASE_REF:-}" ]; then
  echo "::group::stet pr lint (PR description format)"
  f_out="$(node -e "const e=require(process.env.GITHUB_EVENT_PATH);process.stdout.write((e.pull_request&&e.pull_request.body)||'')" | $STET pr lint - 2>&1)"; format_rc=$?
  echo "$f_out"; echo "::endgroup::"
  { echo "#### PR description format"; echo '```'; echo "$f_out"; echo '```'; } >> "$SUMMARY"
  if [ $format_rc -ne 0 ]; then echo "::error title=Stet PR format::The PR description doesn't follow this repo's format. Regenerate it with: stet pr --what \"<why>\""; fi
fi

fails=0; [ $guard_rc -ne 0 ] && fails=$((fails+1)); [ $check_rc -ne 0 ] && fails=$((fails+1)); [ $format_rc -ne 0 ] && fails=$((fails+1))
if [ $fails -gt 1 ]; then result=failed
elif [ $guard_rc -ne 0 ]; then result=guard-failed
elif [ $check_rc -ne 0 ]; then result=check-failed
elif [ $format_rc -ne 0 ]; then result=format-failed
else result=pass; fi
echo "result=$result" >> "$OUTPUT"
echo "" >> "$SUMMARY"; echo "<sub>[Stet](https://getstet.dev) · result: **$result**</sub>" >> "$SUMMARY"
[ "$result" = "pass" ] || exit 1
