#!/usr/bin/env bash
# reset-demo.sh — seed an empty demo workspace, or restore a used one to its pristine state.
#
# A real /run-unbound-demo legitimately writes local state — the only writes ADR-4 permits:
#   * state/run-state.yaml         advance last_run; flip processing_status to processed on the
#                                  contributing event_ids[] ONLY, at close-out (never at plan
#                                  generation); and the work[] in-flight record's whole lifecycle —
#                                  created by work-account RECORD WORK when the plan is generated,
#                                  advanced planned -> triaged -> executed, and REMOVED at `closed`
#                                  in the same write that flips those events
#   * accounts|projects/<slug>/drafts/<plan_date>-tasks.yaml   handled_on rewritten onto a task by
#                                  the loop, recording that it was given its turn
#   * state/feedback-log.jsonl     one appended JSON line per captured verdict
#   * accounts|projects/<slug>/drafts/<today>-{tasks.yaml,email.md,crm-update.md}   newly minted
#   * accounts|projects/<slug>/context.md   a new "## Activity Log" entry appended (work-account §8)
# so a second showing would otherwise start from mutated state and produce a shrunken slate.
#
# This script copies a pristine snapshot (the seed) over those files and deletes run-generated
# draft files that are not part of the seed. Bootstrapping an empty workspace and resetting a used
# one are the same code path: `mkdir -p` + `cp` per seed file creates missing parents, so an empty
# directory becomes a complete workspace with no separate first-run branch.
#
# Seed resolution, in order:
#   1. $SCRIPT_DIR/demo/seed   built-artifact layout (script at resources/reset-demo.sh,
#                              seed at resources/demo/seed/)
#   2. $SCRIPT_DIR/seed        repo layout (runtime/demo/reset-demo.sh beside runtime/demo/seed/)
#   Neither resolves -> exit 2, naming both probed paths.
#
# Target: the current working directory. The demo workspace is a disposable folder the presenter
# runs this from — never the directory this script lives in. A working directory holding both
# skills/ and runtime/ is an Unbound corpus checkout, not a demo workspace, and is refused before
# anything is computed or printed, in every mode.
#
# Usage:
#   reset-demo.sh                 Restore the seed + remove run-generated drafts (idempotent) —
#                                 the full "start the demo over" reset, and the bootstrap path.
#   reset-demo.sh --state-only    Restore ONLY state/run-state.yaml (resets the last_run anchor,
#                                 returns every event to pending, and drops any work[] record left
#                                 in flight). Touches nothing else — a fast
#                                 "re-show the slate" path. Drafts and feedback-log are left as-is,
#                                 so for a truly fresh showing prefer the full reset above.
#   reset-demo.sh --check         Print exactly what it WOULD restore/remove; perform NO writes.
#                                 Composable with --state-only, in either order.
#
# Exit codes: 0 = reset done, or a clean preview.
#             2 = usage error, unresolvable seed, refused target, or --state-only with no
#                 state/run-state.yaml in the seed.
# No exit path reports a failure and returns 0.
#
# Bash idioms mirror runtime/build-cowork-bundle.sh: set -euo pipefail, BASH_SOURCE-relative
# paths, idempotent, a --check preview mode. Written to run on stock macOS bash 3.2.
set -euo pipefail

usage() { echo "Usage: $(basename "$0") [--state-only] [--check]" >&2; }

# ── Resolve this script's own directory ───────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Argument parsing ──────────────────────────────────────────────────────────────────────────
CHECK_MODE=0
STATE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_MODE=1 ;;
    --state-only) STATE_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    --) break ;;
    *) echo "ERROR: unknown argument: $arg" >&2; usage; exit 2 ;;
  esac
done

# ── Target, and the corpus-checkout guard ─────────────────────────────────────────────────────
# The target is the working directory, never a path derived from this script's location.
TARGET="$PWD"

if [ -d "$TARGET/skills" ] && [ -d "$TARGET/runtime" ]; then
  echo "ERROR: refusing to seed $TARGET" >&2
  echo "       it holds both skills/ and runtime/, so it looks like an Unbound corpus checkout," >&2
  echo "       not a demo workspace. cd into the disposable demo workspace and re-run." >&2
  exit 2
fi

# ── Dual seed resolution: bundle layout first, repo layout second ─────────────────────────────
SEED_BUNDLE="$SCRIPT_DIR/demo/seed"
SEED_REPO="$SCRIPT_DIR/seed"
if [ -d "$SEED_BUNDLE" ]; then
  SEED="$SEED_BUNDLE"
elif [ -d "$SEED_REPO" ]; then
  SEED="$SEED_REPO"
else
  echo "ERROR: seed snapshot not found. Probed both supported layouts:" >&2
  echo "       bundle: $SEED_BUNDLE" >&2
  echo "       repo:   $SEED_REPO" >&2
  exit 2
fi

# ── Plan ────────────────────────────────────────────────────────────────────────────────────
# RESTORE: every file under the seed, as a path relative to the target workspace root.
SEED_LIST="$(cd "$SEED" && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | sort)"

# --state-only narrows the restore to run-state.yaml and skips ALL draft removal (a fast
# "reset the clock to re-show the slate" path). Otherwise restore the full run-mutated surface.
if [ "$STATE_ONLY" -eq 1 ]; then
  SEED_LIST="$(printf '%s\n' "$SEED_LIST" | grep -xF 'state/run-state.yaml' || true)"
  [ -n "$SEED_LIST" ] || { echo "ERROR: state/run-state.yaml not found in seed: $SEED" >&2; exit 2; }
fi

# REMOVE: every live file under accounts|projects/*/drafts/ that is NOT present in the seed
# (i.e. run-generated drafts — today's email/crm-update and any newly minted tasks.yaml).
# Skipped entirely in --state-only mode.
live_drafts() {
  local d
  for d in accounts projects; do
    [ -d "$TARGET/$d" ] || continue
    ( cd "$TARGET" && find "$d" -type f -path '*/drafts/*' ! -name '.DS_Store' )
  done | sort
}

REMOVE_LIST=""
if [ "$STATE_ONLY" -eq 0 ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if ! printf '%s\n' "$SEED_LIST" | grep -qxF "$rel"; then
      REMOVE_LIST="${REMOVE_LIST}${rel}"$'\n'
    fi
  done < <(live_drafts)
fi

# ── Report the plan ─────────────────────────────────────────────────────────────────────────
MODE_LABEL=""
[ "$STATE_ONLY" -eq 1 ] && MODE_LABEL=" [state-only]"
[ "$CHECK_MODE" -eq 1 ] && MODE_LABEL="$MODE_LABEL (--check)"
echo "==> Unbound demo reset$MODE_LABEL"
echo "    seed:   $SEED"
echo "    target: $TARGET"
echo ""

echo "==> Restore (seed -> workspace):"
printf '%s\n' "$SEED_LIST" | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  echo "    restore  $rel"
done

if [ -n "$REMOVE_LIST" ]; then
  echo "==> Remove (run-generated, not in seed):"
  printf '%s' "$REMOVE_LIST" | while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    echo "    remove   $rel"
  done
else
  echo "==> Remove (run-generated, not in seed): none"
fi

if [ "$CHECK_MODE" -eq 1 ]; then
  echo ""
  echo "==> --check: no writes performed."
  exit 0
fi

# ── Apply ───────────────────────────────────────────────────────────────────────────────────
printf '%s\n' "$SEED_LIST" | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  mkdir -p "$TARGET/$(dirname "$rel")"
  cp "$SEED/$rel" "$TARGET/$rel"
done

if [ -n "$REMOVE_LIST" ]; then
  printf '%s' "$REMOVE_LIST" | while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    rm -f "$TARGET/$rel"
  done
fi

echo ""
echo "==> Done: workspace restored to its pristine pre-run state."
