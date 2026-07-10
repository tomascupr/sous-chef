#!/usr/bin/env bash
# sous-chef self-checks - "claims are not evidence", applied to the repo's own text.
# The value is this executable invariant list; CI just runs it (issue #8).
# Deterministic except the link sweep, which fails only on hard 404/410
# (transient codes and bot-blocks warn). SKIP_LINKS=1 skips the sweep.
set -u
cd "$(dirname "$0")/.."

fail=0
ok()   { printf 'ok   %s\n' "$1"; }
err()  { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }
warn() { printf 'warn %s\n' "$1"; }
section_ok() { [ "$fail" -eq "$mark" ] && ok "$1"; mark=$fail; }
mark=0

# 1. Manifest sanity ----------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  if out=$(claude plugin validate . 2>&1); then
    ok "claude plugin validate"
  else
    err "claude plugin validate:"; printf '%s\n' "$out"
  fi
else
  warn "claude CLI not installed - skipping plugin validate (CI runs it)"
fi
mark=$fail

# 2. Skill frontmatter --------------------------------------------------------
# CLAUDE.md rule: no ": " inside a description - YAML plain scalars break on it.
for f in skills/*/SKILL.md; do
  desc=$(sed -n 's/^description: //p' "$f")
  [ -n "$desc" ] || { err "$f: no description in frontmatter"; continue; }
  case $desc in
    *": "*) err "$f: ': ' inside description breaks YAML plain scalars - use ' - '" ;;
  esac
done
section_ok "skill frontmatter"

# 3. Cross-file invariants ----------------------------------------------------
# Every field a reader parses from another skill's artifact is named by its writer.
must_contain() { # file fixed-string reason
  grep -qF -- "$2" "$1" || err "$1 must contain '$2' - $3"
}
must_contain skills/serve/SKILL.md  'started:'  "the receipt template reads state.md's started: for wallclock"
must_contain skills/simmer/SKILL.md 'started:'  "the receipt template reads loop.md's started: for wallclock"
must_contain skills/serve/SKILL.md  'findings:' "refire (via serve) reads state.md's findings: line"
must_contain skills/serve/SKILL.md  'baseline:' "taste's post-fire scope reads state.md's baseline: line"
must_contain skills/taste/SKILL.md  'tree:'     "refire's preflight reads findings.md's tree: anchor"

# The taste/refire tree anchor is one recipe, spelled identically on both sides.
ANCHOR='$(git rev-parse --short HEAD)+$(idx=$(mktemp -u); GIT_INDEX_FILE=$idx git add -A && GIT_INDEX_FILE=$idx git write-tree | cut -c1-12)'
must_contain skills/taste/SKILL.md  "$ANCHOR" "taste writes the anchor refire recomputes"
must_contain skills/refire/SKILL.md "$ANCHOR" "refire recomputes the anchor taste writes"

# Every skill that backgrounds a worker carries the no-nested-backgrounding rule -
# literally (nohup named) or by an explicit pointer to fire's rule. Match the word
# "backgrounded" too, not just the Bash annotation: refire and simmer background
# workers by cross-reference without repeating the invocation block.
for f in $(grep -rlE 'run_in_background: true|backgrounded' skills/); do
  grep -qE 'nohup|backgrounding rule' "$f" || err "$f backgrounds a worker but carries neither the no-&/nohup/disown rule nor a pointer to fire's"
done

# One ledger line schema, defined once (fire); each writer names its own skill tag.
n=$(grep -rlF '{"ts":' skills/ | wc -l | tr -d ' ')
[ "$n" = 1 ] || err "ledger line schema must be defined in exactly one file (found $n)"
for s in taste refire simmer; do
  must_contain "skills/$s/SKILL.md" "\"skill\":\"$s\"" "its ledger lines carry its own skill tag"
done

# Every plugin-root path a skill or template names actually ships in the repo.
for p in $(grep -rho 'CLAUDE_PLUGIN_ROOT}/[A-Za-z0-9._/-]*' skills/ templates/ | sed 's|^CLAUDE_PLUGIN_ROOT}/||' | sort -u); do
  [ -e "$p" ] || err "\${CLAUDE_PLUGIN_ROOT}/$p is referenced but does not exist"
done

# Every relative markdown link inside skills/ resolves.
for f in $(find skills -name '*.md'); do
  for l in $(grep -o ']([^)]*)' "$f" | sed 's/^](//; s/)$//'); do
    case $l in http*|'#'*) continue ;; esac
    [ -e "$(dirname "$f")/${l%%#*}" ] || err "$f links $l which does not exist"
  done
done
section_ok "cross-file invariants"

# 4. Link sweep ---------------------------------------------------------------
# Every receipt cites a URL; dead links rot the receipts. Hard 404/410 fails.
if [ "${SKIP_LINKS:-}" != 1 ]; then
  for u in $(grep -rhoE 'https?://[^) >"`]+' README.md docs/design.md | sed 's/[.,;]$//' | sort -u); do
    code=$(curl -sL -o /dev/null -w '%{http_code}' --max-time 10 \
      -A 'Mozilla/5.0 (sous-chef link check)' "$u" 2>/dev/null)
    case $code in
      2*|3*) ;;
      404|410) err "dead link ($code): $u" ;;
      *) warn "link returned $code (not failing - transient or bot-blocked): $u" ;;
    esac
  done
  section_ok "link sweep"
fi

if [ "$fail" -eq 0 ]; then echo "all checks passed"; else echo "$fail check(s) FAILED"; fi
exit $((fail > 0))
