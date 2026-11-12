#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# NOVA – Beyond the Mission | prove the release artefacts are a real delivery.
#
# WHY THIS EXISTS
#   `make_release.sh` produces a patch and a zip, and `sha256sum -c` proves they
#   were not corrupted. Neither proves they *work*. Five deliveries were pushed
#   inside a wrapper directory, so GitHub never ran a single gate – and a patch
#   whose baseline commit no longer exists (a squashed history) cannot be applied
#   at all. Both failures are invisible until someone tries the delivery.
#
#   This script tries it, on throwaway clones, in four moves:
#     1. the checksums match the artefacts that are actually there
#     2. `git am` on a clean clone of the baseline reproduces the delivered tree
#     3. the zip, extracted and uploaded as *contents*, passes the layout guard
#     4. the same zip uploaded as a *folder* is rejected by that guard
#
#   Step 4 is a negative test on purpose: a guard that never fails is not a guard.
#
# USAGE
#   bash tools/verify_delivery.sh --base 5ee0295
#   bash tools/verify_delivery.sh --base origin/main --name nova-backend-final
#
# Needs only bash, git and python3 – no virtualenv, no network.
# ---------------------------------------------------------------------------
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)" || exit 1
cd "$ROOT"

BASE=""
NAME="nova-backend-final"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:?--base needs a revision}"; shift ;;
    --name) NAME="${2:?--name needs a value}"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
if [[ -z "$BASE" ]]; then
  echo "usage: bash tools/verify_delivery.sh --base <baseline-commit> [--name <artefact-name>]" >&2
  exit 2
fi
if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
  echo "✗ baseline '$BASE' is not in this repository – the patch cannot be tested against it." >&2
  exit 2
fi

PATCH="releases/$NAME.patch"
ZIP="releases/$NAME.zip"
for artefact in "$PATCH" "$ZIP" releases/SHA256SUMS.txt; do
  [[ -f "$artefact" ]] || { echo "✗ missing $artefact – run: bash tools/make_release.sh --base $BASE" >&2; exit 1; }
done

TEST="$(mktemp -d)"
trap 'rm -rf "$TEST"' EXIT
fail() { printf '✗ %s\n' "$*" >&2; exit 1; }

echo "═══ 1. checksums ═══════════════════════════════════════════════════════"
(cd releases && sha256sum -c SHA256SUMS.txt) || fail "the artefacts do not match SHA256SUMS.txt"

echo
echo "═══ 2. git route: git am on a clean clone of $BASE ═════════════════════"
git clone -q "$ROOT" "$TEST/baseline" || fail "clone failed"
(
  cd "$TEST/baseline" || exit 1
  git checkout -q "$BASE" || exit 1
  git config user.name "Delivery Test"
  git config user.email "test@localhost"
  # The guard prints absolute paths; normalise the throwaway directory so this
  # log is byte-identical on every run and can be committed as evidence.
  # On a wrapped baseline the guard itself is one level down – find it, so the
  # "before" line shows the real defect instead of a missing-file error.
  GUARD=tools/check_layout.sh
  [[ -f "$GUARD" ]] || GUARD="$(git ls-files '*/tools/check_layout.sh' | head -1)"
  echo "-- layout as it arrived:"
  bash "$GUARD" 2>&1 | sed "s#$TEST#<tmp>#g"
  echo "-- applying $PATCH:"
  git am "$ROOT/$PATCH" >/dev/null 2>&1 || exit 1
  # The commit id depends on the committer clock; the tree does not.
  git log -1 --format='-- applied: %s'
  echo "-- resulting tree: $(git rev-parse 'HEAD^{tree}')"
  echo "-- layout after the patch:"
  bash tools/check_layout.sh 2>&1 | sed "s#$TEST#<tmp>#g" || exit 1
) || fail "git am did not produce a tree GitHub will run CI on"

python3 - "$ROOT" "$TEST/baseline" <<'PY' || fail "the patched clone is not the delivered tree"
import hashlib, pathlib, subprocess, sys

delivery, clone = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
GENERATED = ("releases/SHA256SUMS.txt", "releases/delivery-roundtrip.log")


def tracked(cwd):
    out = subprocess.run(["git", "ls-tree", "-r", "--name-only", "HEAD"],
                         cwd=cwd, capture_output=True, text=True, check=True).stdout
    return set(out.split())


def generated(name):
    return name in GENERATED or (
        name.startswith("releases/") and name.endswith((".zip", ".patch"))
    )


a, b = tracked(clone), tracked(delivery)
# The generated artefacts are deliberately not carried by the patch, so compare
# the *source* tree: everything a human wrote must match, file for file.
a = {f for f in a if not generated(f)}
b = {f for f in b if not generated(f)}
print(f"-- source files: patched clone {len(a)} | delivery HEAD {len(b)}")
print("-- only in delivery:", sorted(b - a) or "none")
print("-- only in clone   :", sorted(a - b) or "none")
mismatch = [
    f for f in sorted(a & b)
    if not generated(f)
    and hashlib.sha256((clone / f).read_bytes()).hexdigest()
    != hashlib.sha256((delivery / f).read_bytes()).hexdigest()
]
print("-- content mismatches (generated artefacts excluded):", mismatch or "NONE")
sys.exit(1 if (b - a) or (a - b) or mismatch else 0)
PY

echo
echo "═══ 3. zip route: extract, then upload the CONTENTS ════════════════════"
mkdir -p "$TEST/empty"
python3 - "$ROOT/$ZIP" "$TEST/empty" <<'PY' || fail "the snapshot is not readable"
import sys, zipfile

with zipfile.ZipFile(sys.argv[1]) as z:
    names = z.namelist()
    print("-- entries:", len(names), "| top level:", sorted({n.split("/")[0] for n in names}))
    print("-- archive comment:", z.comment or b"(none)")
    modes = {oct(i.external_attr >> 16) for i in z.infolist() if not i.filename.endswith("/")}
    print("-- file modes:", sorted(modes))
    z.extractall(sys.argv[2])
PY
(
  cd "$TEST/empty/NOVA" || exit 1
  [[ -f .github/workflows/backend.yml ]] || exit 1
  git init -q .
  git add -A
  echo "-- guard on the extracted CONTENTS (the correct GitHub upload):"
  bash tools/check_layout.sh
) || fail "the extracted contents do not pass the layout guard"

echo
echo "═══ 4. negative test: uploading the folder itself must be rejected ═════"
(
  cd "$TEST/empty" || exit 1
  git init -q . 2>/dev/null
  git add -A >/dev/null 2>&1
  if bash NOVA/tools/check_layout.sh 2>&1 | sed "s#$TEST#<tmp>#g"; then
    echo "✗ the guard did NOT catch the wrapper" >&2
    exit 1
  fi
  echo "✓ wrapper rejected – this is the trap that broke six deliveries"
) || fail "the layout guard is not catching the wrapper"

echo
echo "✓ both delivery routes reproduce a CI-visible tree, and the wrapper trap is caught"