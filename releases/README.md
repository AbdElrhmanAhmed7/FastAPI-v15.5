# releases · Delivery package

The files here are **generated from a commit**, not from the working tree. The goal:
anyone can take the delivery and apply it to their copy without copying `.venv`, caches,
or a local database.

## Current delivery: v15 layout repair + verification

This package is generated above the GitHub baseline `5ee0295` (`v15`) of
**`AbdElrhmanAhmed7/FastAPI-v15`** — an upload that arrived **inside a `Final/` wrapper**,
because the *workspace* folder was uploaded rather than the repository inside it.
GitHub consequently discovered **zero workflows and ran zero jobs**: the workflow sat
at `Final/.github/workflows/backend.yml`, where GitHub never looks.

* **The layout was repaired first.** `tools/restructure_repo.sh` promoted the project
  to the git root with `git mv` (history follows the files), and
  `bash tools/check_layout.sh` now passes. This patch carries that repair, so applying
  it to a clean clone of `5ee0295` fixes CI discovery in one step.
* Every gate was then re-run from scratch on the repaired tree (new clone, new
  virtualenv): **451 tests · 94% coverage · 15/15 missions · 67/67 operations audited
  for player text (in-process and over a real socket) · 12 offline + 14 live probes ·
  0 failures** (NASA POWER `live`). Evidence: `verification/2026-11-12-v15/`.
* **Both artefacts had to be regenerated.** The history was squashed again, so the old
  baselines (`24dc3e6`, `bbfa863`, `fd73e5a`) no longer exist and the committed patch
  failed to apply; the zip was absent because `releases/*.zip` is gitignored. See "A
  squashed history retires the patch" below.
* **The delivery is now tested, not assumed.** `bash tools/verify_delivery.sh --base 5ee0295`
  checks the sums, applies this patch to a throwaway clone and compares every file,
  extracts the zip and runs the layout guard on its contents — and confirms the guard
  *rejects* the same zip uploaded as a folder.
* The delivery documents pointed at `Final-v14.5` / `bbfa863`; they now name
  `AbdElrhmanAhmed7/FastAPI-v15` / `5ee0295` (`PROJECT_STATUS.md` §9.9 and §13,
  `MIGRATION.md` §12, `verification/README.md`). Earlier sections stay as history.

Earlier packages are already merged in this tree: the layout migration (`git mv` out of
`repo/`, fifth occurrence) and the English localization (baseline `a2fd1cc`) — all
player-facing content and documentation are English, the legacy `ar` locale field is
retained as an English alias, and `tests/test_english_content.py` guards against Arabic
text returning to content, API payloads or the console.

## How they are generated

```bash
git commit -m "…"                        # the tree must be clean
bash tools/make_release.sh --base <commit>   # default: origin/main
```

The script refuses to run if there are uncommitted changes (`git status --porcelain`) —
because a delivery package that does not match any commit is not reviewable.

| File | What it is | How to use it |
| --- | --- | --- |
| `nova-backend-final.patch` | This delivery's commit delta above the base (`git format-patch`, generated artefacts excluded) | `git am releases/nova-backend-final.patch` on a clean clone of `5ee0295` |
| `nova-backend-final.zip` | Full tree snapshot (`git archive HEAD`) without the generated artefacts | Extract into an **empty** folder, then `cd NOVA` and upload **everything inside it** — see the warning below |
| `SHA256SUMS.txt` | SHA-256 hashes of the files generated in the last run | `sha256sum -c releases/SHA256SUMS.txt` |
| `delivery-roundtrip.log` | The output of `tools/verify_delivery.sh`: both routes applied to throwaway clones, and the wrapper rejected | `bash tools/verify_delivery.sh --base 5ee0295` |

The patch contains the layout repair (`git mv` out of `Final/`), the v15 delivery
documents, the v15 verification evidence, and `tools/verify_delivery.sh`.
Only the **generated artefacts** (`*.zip`, `*.patch`, `SHA256SUMS.txt`) are excluded, so
the patch never contains a copy of itself — but this `README.md` **is** included in both
the patch and the zip. It used to be excluded along with the whole `releases/` folder,
which meant the delivery instructions (including the `NOVA/` prefix warning below)
reached nobody who used `git am` or the zip.

`delivery-roundtrip.log` is committed but **excluded from the patch and the zip**, like
the artefacts themselves: it describes applying this package, so packaging it would be
circular — the log would have to exist before the package it verifies. It is written to
be byte-identical on every run (temporary paths normalised, tree hash instead of commit
id), so re-running the check leaves the working tree clean.

## The snapshot is byte-reproducible

`git archive` stamps the archive with the **commit** id (as the zip comment) and the
commit time (as every member's mtime). Two commits with an *identical tree* therefore
produce different bytes — which quietly broke `SHA256SUMS.txt`: committing the sums
creates a new commit, so the recorded zip hash never matched the zip regenerated from
that commit.

`tools/make_release.sh` now normalises that metadata: fixed timestamp, sorted entries,
no archive comment, and the **tracked file modes** written explicitly (`git archive`
leaves them empty, so a plain `unzip` falls back to its own defaults). The snapshot is a
function of the **tree** alone, so regenerating it after a `releases/`-only commit yields
the same hash and `sha256sum -c SHA256SUMS.txt` keeps passing. The patch is reproducible
for the same reason: `releases/` is excluded from it, so a release commit does not change
it.

## A squashed history retires the patch

A patch is a delta **between two commits**. `git format-patch base..HEAD` is only
applyable while `base` still exists in the target repository and the delta is not
already there. The `v14.5` upload arrived as a **single squashed commit**, which broke
both conditions at once:

```
$ git cat-file -t 24dc3e6
fatal: Not a valid object name 24dc3e6
$ git am releases/nova-backend-final.patch
error: .github/workflows/backend.yml: patch does not apply
error: verification/2026-11-12-v14/gates.log: already exists in index
$ git am -3 releases/nova-backend-final.patch
error: could not build fake ancestor
```

Nothing was wrong with the code — the delta was simply already merged. **After any
squash, rebase or fresh upload, regenerate the package against the commit that is
actually on GitHub:**

```bash
bash tools/make_release.sh --base bbfa863
```

The zip is unaffected by history rewrites: it is a function of the tree alone (see
above), so the same content always produces the same archive.

## Why the zip is not committed to git

The `.zip` is placed in `.gitignore`: it is a copy of the same commit tree, so storing it
inside git duplicates history and grows the repo for no benefit, and every release can
regenerate it in a second. The **patch** is committed because it is reviewable text in
the diff, and `SHA256SUMS.txt` records the hash of the zip generated alongside it so you
can verify that your copy is identical.

```bash
bash tools/make_release.sh --base bbfa863        # the baseline pushed to AbdElrhmanAhmed7/Final-v14.5
cd releases && sha256sum -c SHA256SUMS.txt && cd ..
```

> **Note:** all filenames are lowercase (`nova-backend-final.*`) because
> `tools/make_release.sh` generates them that way. The documentation used to say
> `NOVA-backend-final.zip` with uppercase letters — fixed to match the script.

## Applying the patch

On a clean clone of the baseline (`bbfa863`):

```bash
git am releases/nova-backend-final.patch
bash tools/check_layout.sh
cd NOVA/backend && make install
bash tools/verify.sh          # all gates + campaign + probes
```

After applying, the repository should pass the English-content gates:

```bash
cd NOVA/backend
.venv/bin/pytest tests/test_english_content.py -q
```

## After applying

```bash
cd NOVA/backend && make install
bash tools/verify.sh          # all gates + campaign + probes
git push origin main          # requires your GitHub permissions
```

After pushing, open the **Actions** tab: a workflow named `backend` must appear and run.
If it does not, `.github/workflows/backend.yml` is not at the **root** of the repository —
see [`MIGRATION.md`](../MIGRATION.md).

## ⚠ The zip has a `NOVA/` prefix folder — do not upload the folder itself

`git archive --prefix=NOVA/` wraps the snapshot in a single top-level directory so
that extracting it never scatters files over your current folder. That convenience is
also the trap that produced **five** wrapped deliveries: if you extract the zip and
drag the `NOVA/` folder onto GitHub's upload page, GitHub stores the folder name in
every path, `.github/workflows/backend.yml` ends up below the git root, and CI runs
nothing at all.

```bash
unzip nova-backend-final.zip -d delivery   # → delivery/NOVA/…
cd delivery/NOVA                           # ← go INSIDE the folder
ls .github/workflows/backend.yml           # must exist here
# select everything here (Ctrl+A) and drag that, never the NOVA folder
```

Using git avoids the whole class of mistake:

```bash
git clone https://github.com/AbdElrhmanAhmed7/Final-v14.5 && cd Final-v14.5
git am /path/to/releases/nova-backend-final.patch
bash tools/check_layout.sh                 # ✓ layout ok
git push origin main
```

After **any** upload or push, `bash tools/check_layout.sh` must say `✓ layout ok`, and
the **Actions** tab must show the `backend` workflow with 3 jobs.
