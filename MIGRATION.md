# MIGRATION · Moving the project to the repository root

**Date: 2026-11-12** · Branch `main` · Base commit `a645012` (`v10.5`)

> A one-time file: it explains what was moved, why, and how to apply the same change
> to any other copy you have and push it to GitHub. If your repo already has the new
> layout, this file is just a record.

---

## 1. The problem that existed (not cosmetic)

The tree pushed to GitHub looked like this:

```
<git root>/
├── repo/
│   ├── .github/workflows/backend.yml     ← GitHub never read this
│   └── NOVA/backend/…                    ← all the code
├── uploads/…                             ← a text file copied from the GitHub UI
├── verification/…
├── NOVA-backend-final.zip
└── nova-backend-finish.patch
```

GitHub reads workflows **only from `<git root>/.github/workflows`**, and the workflow
itself says `paths: ["NOVA/backend/**"]` and `working-directory: NOVA/backend`.
Both were one level too deep, so the result was:

* **Not a single job ran on any push.** Every gate (ruff · mypy · content · audit ·
  contract · pytest · campaign) was decoration on GitHub.
* The tests could not see the defect, because they looked for the **nearest** directory
  containing `.github/workflows` and treated it as the repository root — so they found
  `repo/` and accepted it. In other words, the gate confirmed that it was correct inside
  the wrong wrapper.

## 2. The new layout

```
<git root>/
├── README.md · PROJECT_STATUS.md · MIGRATION.md
├── .github/workflows/backend.yml         ← GitHub sees it now
├── NOVA/backend/…                        ← unchanged, not a line of code moved
├── tools/                                ← verify.sh · make_release.sh · restructure_repo.sh
├── verification/                         ← run evidence (dated) + archive/
├── releases/                             ← generated patch and zip
└── reference/scratch/                    ← payload-capture harness
```

### Migration table

| Before | After | Note |
| --- | --- | --- |
| `repo/.github/` | `.github/` | This is what actually runs CI |
| `repo/NOVA/` | `NOVA/` | The same path the workflow points to |
| `repo/README.md` | `README.md` | |
| `repo/PROJECT_STATUS.md` | `PROJECT_STATUS.md` | |
| `repo/reference/` | `reference/` | |
| `repo/.gitignore` | `.gitignore` | |
| `verification/*.log`, `campaign.json` | `verification/archive/` | Previous session runs (history) |
| `NOVA-backend-final.zip` | `releases/nova-backend-final.zip` | Regenerated after the move |
| `nova-backend-finish.patch` | *(removed)* | Already applied in `main` — see §3 |
| `uploads/…txt` | *(removed)* | Text copied from the GitHub UI, not project content |

Every move used `git mv`, so file history (`git log --follow`) is preserved.

## 3. Why was the old patch removed?

`nova-backend-finish.patch` was the previous session's delta, and it is **already
applied** in `main` (commit `a645012`). The `git am nova-backend-finish.patch`
instructions that were in `PROJECT_STATUS.md` would have failed or duplicated work.
The new patch in `releases/` is **this session's delta only** above `a645012`, and the
instructions were updated. The old file is still in git history if anyone needs it:

```bash
git show a645012:nova-backend-finish.patch > /tmp/old.patch
```

## 4. How to apply the migration to another copy

If you have an old clone that still contains `repo/` (or any other wrapper — see §7):

```bash
bash tools/restructure_repo.sh --dry-run   # show the steps without executing
bash tools/restructure_repo.sh             # execute (idempotent – safe to repeat)
```

The script is not tied to the name `repo/`: it looks for any immediate directory inside
the git root that contains `NOVA/backend` and treats it as the wrapper. If it finds more
than one, it refuses to guess.

Or simply pull the new commit: `git pull origin main` — the migration is inside it.

**Practical note:** if you have an old `.venv` inside `repo/NOVA/backend/.venv`, the
absolute paths inside its scripts will be wrong after the move. The easiest fix:

```bash
cd NOVA/backend && rm -rf .venv && make install
# or without make:
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
```

## 5. Verify before pushing

```bash
bash tools/verify.sh          # all gates + campaign, writes verification/<date>/gates.log
```

What you must see: `✓ all gates passed`, and `15 / 15` missions in the campaign report.
After pushing, open the **Actions** tab on GitHub: a workflow named `backend` should
appear and run — this is the first time it actually runs.

## 6. Pushing

```bash
git push origin main
```

This requires your GitHub permissions (the environment where the migration was done
could not push). If `git` asks for credentials or returns an authentication error,
reconnect your GitHub account in Arena.

---

## English summary

The delivered tree wrapped the project in `repo/`, so `.github/workflows` sat one
level below the git root and the workflow's own filters (`NOVA/backend/**`) did
not match the real paths: **CI never ran**. This migration promotes the project
to the git root with `git mv` (history preserved), files the previous run logs
under `verification/archive/`, regenerates the delivery artefacts into
`releases/`, and drops a stray `uploads/` text file plus the already-merged
patch. The repository gates now anchor on the **git root**
(`tests/conftest.py::repository_root`) instead of the nearest `.github`
directory, so the same mistake fails the suite instead of passing quietly.
Apply it elsewhere with `bash tools/restructure_repo.sh`, verify with
`bash tools/verify.sh`, then `git push origin main`.

---

## 7. The problem repeated: the `upstream/` wrapper (third session)

**Date: 2026-11-12** · The commit that arrived from GitHub: `9c4873f` (`v11`)

The version pushed to `AbdElrhmanAhmed7/FastAPI-v11` looked like this:

```
<git root>/
└── upstream/
    ├── .github/workflows/backend.yml   ← GitHub never read this (again)
    ├── NOVA/backend/…
    ├── README.md · PROJECT_STATUS.md · MIGRATION.md
    ├── tools/ · verification/ · reference/
```

Exactly the same defect, just with a different wrapper name (`upstream/` instead of
`repo/`). The result:

* **Not a single job would run** on any push — the workflow was one level below the git
  root, and its filters (`paths: ["NOVA/backend/**"]`) did not match the real path
  (`upstream/NOVA/backend/**`).
* This time **the tests caught the defect immediately**: the first `pytest` run on a
  clean clone from GitHub returned **8 failed + 4 errors** — all in
  `test_project_docs.py` and `test_ci_workflow.py`. The failure happened because
  `conftest.repository_root()` anchors on `.git` (as introduced in §1), so it found the
  real root empty of `README.md` and `.github/workflows`. In other words, the gate built
  to prevent this mistake actually worked.

### What was done

| Step | Command |
| --- | --- |
| Detect the wrapper and move everything to the root with `git mv` | `bash tools/restructure_repo.sh` |
| Generalise the script to any wrapper name (not just `repo/`) | `tools/restructure_repo.sh` |
| Rebuild `.venv` after the move (absolute paths break) | `cd NOVA/backend && make install` |
| Re-run every gate | `bash tools/verify.sh --live` |

After the move: **437 tests passing, 0 failures**, and `✓ all gates passed`.

### The lesson

The wrapper is not fixed by renaming the folder; it is fixed by making
**git root = project root**. If you upload the tree to GitHub manually, upload the
**contents** of the folder, not the folder itself:

```bash
cd <git root>
git add -A && git commit -m "…" && git push origin main
ls .github/workflows/backend.yml   # must exist
```

And after any push: the **Actions** tab must show the `backend` workflow. If it is empty,
there is another wrapper.

---

## 8. The wrapper returned a third time: `repo/` in `FastAPI-v11.5` (fourth session)

**Date: 2026-11-12** · The commit that arrived from GitHub: `434b2e3` (`v11.5`) ·
Repo: `AbdElrhmanAhmed7/FastAPI-v11.5`

```
<git root>/
└── repo/
    ├── .github/workflows/backend.yml   ← GitHub never read this (third time)
    ├── NOVA/backend/…
    ├── README.md · PROJECT_STATUS.md · MIGRATION.md
    ├── tools/ · verification/ · releases/ · reference/
```

So after two full sessions fixing the same defect, the tree was pushed inside a wrapper
again. The confirmed result: **not a single job would run** on that repo — no lint, no
tests, no campaign. Every number in the documentation was correct *locally*, and CI
could not see it.

### Why does it keep happening?

The mistake is not in the code; it is in **the upload method**. Uploading a whole folder
through the GitHub UI (Add file → Upload files), or extracting an archive that contains a
root folder, makes GitHub store the folder itself as part of the path. The project then
becomes `<root>/repo/…` instead of `<root>/…`. The fix is not renaming the folder — the
fix is **git root = project root**.

### What was done

| Step | Command |
| --- | --- |
| Detect the wrapper and move everything to the root with `git mv` (history preserved) | `bash tools/restructure_repo.sh` |
| New layout gate needing only bash + git (0.1 seconds) | `bash tools/check_layout.sh` |
| Wire it as the first verification gate, before the `.venv` check | `tools/verify.sh` |
| 9 regression tests that plant the mistake in temporary repositories | `tests/test_repo_layout_guard.py` |
| Re-run all gates + campaign + probes | `bash tools/verify.sh --live` |

After the move: **446 tests passing, 0 failures**, `✓ all gates passed`, and
**14 probes · 0 failures** against a real uvicorn server.

### What exactly does the new gate reject?

1. `NOVA/backend` is not at the git root.
2. `.github/workflows/backend.yml` is missing from the root.
3. Any subdirectory containing a second copy of the project (**any name** — `repo/`,
   `upstream/`, `NOVA-main/` … not a saved list of names).
4. Any workflow buried below the root (GitHub ignores it silently).
5. `paths:` filters or `working-directory` in the workflow that do not match the real
   path.

If you copied the tree without `.git` (zip), the gate says “skipped” instead of failing
for the wrong reason.

### The correct way to push (choose one)

```bash
# (a) git — preferred, history preserved
git clone https://github.com/AbdElrhmanAhmed7/FastAPI-v11.5 && cd FastAPI-v11.5
git am /path/to/releases/nova-backend-final.patch
bash tools/check_layout.sh                  # ✓ layout ok
git push origin main

# (b) Manual upload through the GitHub UI — drag the *contents* of the folder, not the folder
#     Open the folder on your machine, select all files (Ctrl+A), and drag them onto the page.
#     Do not drag the folder itself.
```

**After any push:** the **Actions** tab must show a workflow named `backend` running
(3 jobs). If it is empty, run `bash tools/check_layout.sh` — it will tell you where the
defect is and name the fix.

---

## 9. Fifth occurrence: `repo/` in `AbdElrhmanAhmed7/Final` (final pass)

**Date: 2026-11-12** · The commit that arrived from GitHub: `11cefe5` (`final`) ·
Repo: `AbdElrhmanAhmed7/Final`

```
<git root>/
└── repo/
    ├── .github/workflows/backend.yml   ← GitHub never read this (fifth time)
    ├── NOVA/backend/…
    ├── README.md · PROJECT_STATUS.md · MIGRATION.md
    ├── tools/ · verification/ · releases/ · reference/
```

The first command run on the fresh clone was the layout gate, and it failed
immediately — exactly as designed:

```
$ bash tools/check_layout.sh
✗ NOVA/backend is not at the git root (<clone>)
  Fix: bash tools/restructure_repo.sh
```

Everything else in the tree was clean: `git status` empty, no stray `*.db`, no
leftover translation script, no stale patch. The defect was **only** the wrapper.

### What was done

| Step | Command |
| --- | --- |
| Promote the project to the git root (191 files, `git mv`, history preserved) | `bash tools/restructure_repo.sh` |
| Confirm GitHub will now see the workflow | `bash tools/check_layout.sh` → `✓ layout ok` |
| Rebuild the virtualenv (moved paths) | `python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt` |
| Re-run every gate with a dated log | `bash tools/verify.sh --label 2026-11-12-final` → **10/10 PASS** |
| Keep a live preview for the user, database under `data/` (ignored) | `NOVA_DATABASE_URL=sqlite+aiosqlite:///./data/nova-preview.db uvicorn app.main:app --host 0.0.0.0 --port 8000` |
| Smoke-test that preview server | `.venv/bin/python ../../reference/scratch/preview_smoke.py --base-url http://127.0.0.1:8000` |
| Regenerate the delivery artefacts from the committed tree | `bash tools/make_release.sh --base 11cefe5` |

Result: **451 tests passing**, coverage **94%**, campaign **15/15 · 93 actions ·
0 mistakes**, player-text audit **67/67 operations · 0 violations** (in-process and
over a real socket), **14 probes · 0 failures** with NASA POWER `live`.

### Why the database belongs in `data/`

A preview server started with `NOVA_DATABASE_URL=sqlite+aiosqlite:///./nova-preview.db`
drops `nova-preview.db`, `-wal` and `-shm` next to the source, where the ignore rules
do not reach them: they show up as untracked files and get committed by `git add -A`.
The default (`./data/nova.db`) and any `data/*.db` path are already ignored by
`NOVA/backend/.gitignore`, and `app/db/session.py` creates the directory itself.
**Keep every local database under `data/`** — then a running server never dirties the
tree, and no ignore rule has to be widened.

### The lesson, one more time

The wrapper is not a code problem, it is an **upload** problem. Five deliveries, five
wrappers (`NOVA/`, `repo/`, `upstream/`, `repo/`, `repo/`). Push with git:

```bash
git clone https://github.com/AbdElrhmanAhmed7/Final && cd Final
git am /path/to/releases/nova-backend-final.patch
bash tools/check_layout.sh        # must say ✓ layout ok
git push origin main
```

If you must use the GitHub UI: open the folder on your machine, select **everything
inside it** (Ctrl+A) and drag that — never the folder itself. Then check the
**Actions** tab: a workflow named `backend` must appear with 3 jobs. If the tab is
empty, there is another wrapper, and `bash tools/restructure_repo.sh` removes it.

---

## 10. Sixth delivery: `NovaAPI-v14` — no migration needed (2026-11-12)

**Repo: `AbdElrhmanAhmed7/NovaAPI-v14`** · commit `24dc3e6` (`v14`) · 203 tracked files

The project was uploaded to a new repository, and this time the tree arrived **at the
git root**. The layout gate passed on the fresh clone, so `tools/restructure_repo.sh`
was **not** needed:

```
$ git clone https://github.com/AbdElrhmanAhmed7/NovaAPI-v14 && cd NovaAPI-v14
$ bash tools/check_layout.sh
✓ layout ok – git root = project root, GitHub will run .github/workflows/backend.yml
```

**GitHub confirmed it independently:** the `backend` workflow is `active`, it triggered
on the push, and all **3 jobs succeeded** — `lint · types · content · contract`,
`pytest (offline)`, `full campaign playthrough`
([run 43252213875](https://github.com/AbdElrhmanAhmed7/NovaAPI-v14/actions/runs/43252213875)).
That is the outcome the previous five deliveries never reached.

| # | Repository / commit | Wrapper on arrival | CI |
| --- | --- | --- | --- |
| 1 | first delivery | `NOVA/` | never ran |
| 2 | second delivery | `repo/` | never ran |
| 3 | third delivery | `upstream/` | never ran |
| 4 | English pass | `repo/` (`novaa/`) | never ran |
| 5 | `Final` · `11cefe5` | `repo/` | never ran |
| 6 | **`NovaAPI-v14` · `24dc3e6`** | **none** | **3/3 jobs green** |

### One gap closed in the workflow itself

The path filters covered `NOVA/backend/**` and the workflow file only. But
`tests/test_project_docs.py` asserts the root documents (mission table, contract
figures, every local link) and `tests/test_repo_layout_guard.py` asserts `tools/` —
so a push that touched only those files skipped CI and could land a broken document
unverified. The filters now include `*.md` and `tools/**`:

```yaml
paths: ["NOVA/backend/**", ".github/workflows/backend.yml", "*.md", "tools/**"]
```

### Keep it this way

```bash
git clone https://github.com/AbdElrhmanAhmed7/NovaAPI-v14 && cd NovaAPI-v14
git am /path/to/releases/nova-backend-final.patch
bash tools/check_layout.sh        # ✓ layout ok
git push origin main
```

If you use the GitHub UI instead, remember the trap documented in
[`releases/README.md`](releases/README.md): the release zip wraps the tree in a `NOVA/`
prefix folder. Open that folder, select **everything inside it** (Ctrl+A) and drag
*that* — never the folder itself. Then confirm the **Actions** tab shows `backend`
with 3 jobs, and `bash tools/check_layout.sh` still says `✓ layout ok`.


---

## 11. Seventh delivery: `Final-v14.5` — layout fine, but the squash retired the patch (2026-11-12)

**Repo: `AbdElrhmanAhmed7/Final-v14.5`** · commit `bbfa863` (`v14.5`) · 217 tracked files

The layout was correct again — no wrapper, no migration, `tools/restructure_repo.sh`
not needed:

```
$ git clone https://github.com/AbdElrhmanAhmed7/Final-v14.5 && cd Final-v14.5
$ bash tools/check_layout.sh
✓ layout ok – git root = project root, GitHub will run .github/workflows/backend.yml
```

GitHub ran the `backend` workflow on the push: **3/3 jobs green**
([run 43258592691](https://github.com/AbdElrhmanAhmed7/Final-v14.5/actions/runs/43258592691)).

| # | Repository / commit | Wrapper on arrival | CI |
| --- | --- | --- | --- |
| 1 | first delivery | `NOVA/` | never ran |
| 2 | second delivery | `repo/` | never ran |
| 3 | third delivery | `upstream/` | never ran |
| 4 | English pass | `repo/` (`novaa/`) | never ran |
| 5 | `Final` · `11cefe5` | `repo/` | never ran |
| 6 | `NovaAPI-v14` · `24dc3e6` | none | 3/3 jobs green |
| 7 | **`Final-v14.5` · `bbfa863`** | **none** | **3/3 jobs green** |

### A new trap: squashing history retires the delivery patch

This upload arrived as **one squashed commit**. The code was fine, but the patch in
`releases/` had been generated as `24dc3e6..fd73e5a` — and `24dc3e6` no longer exists
in this repository, while the delta itself is already inside `bbfa863`:

```
$ git cat-file -t 24dc3e6
fatal: Not a valid object name 24dc3e6
$ git am releases/nova-backend-final.patch
error: .github/workflows/backend.yml: patch does not apply
error: verification/2026-11-12-v14/gates.log: already exists in index
```

**Rule:** a delivery patch is only meaningful against the commit that is actually on
GitHub. After any squash, rebase or fresh upload, regenerate it:

```bash
bash tools/make_release.sh --base <the commit on GitHub>
```

The zip needs regenerating for a different reason: `releases/*.zip` is gitignored, so
it never travels with the clone and `sha256sum -c SHA256SUMS.txt` fails until the tool
has been run once. Both artefacts were regenerated above `bbfa863`.

### Keep it this way

```bash
git clone https://github.com/AbdElrhmanAhmed7/Final-v14.5 && cd Final-v14.5
git am /path/to/releases/nova-backend-final.patch
bash tools/check_layout.sh        # ✓ layout ok
git push origin main
```

If you use the GitHub UI instead, remember the trap documented in
[`releases/README.md`](releases/README.md): the release zip wraps the tree in a `NOVA/`
prefix folder. Open that folder, select **everything inside it** (Ctrl+A) and drag
*that* — never the folder itself. Then confirm the **Actions** tab shows `backend`
with 3 jobs, and `bash tools/check_layout.sh` still says `✓ layout ok`.

---

## 12. Eighth delivery: `FastAPI-v15` — the wrapper came back as the workspace folder (2026-11-12)

> **Superseded by §13.** The rule below — *upload the repository, not the workspace* —
> was addressed to the wrong party. The upload was already correct; the workspace
> layout created the wrapper. §13 fixes the cause.

**Repo: `AbdElrhmanAhmed7/FastAPI-v15`** · commit `5ee0295` (`v15`) · 233 tracked files

The sixth occurrence, and a new variant. The previous five wrappers were the release
zip's `NOVA/` prefix or a `repo/` folder. This time the **workspace directory** was
uploaded — the folder that *contains* the repository — so the project arrived one
level down, together with two files that were never part of it:

```
<git root>/
├── Final/          ← .github/, NOVA/, tools/, … (230 files)
├── .scratch/       ← throwaway scripts from the previous session
└── HANDOVER.md
```

### Measured, not inferred

```
$ bash tools/check_layout.sh
✗ NOVA/backend is not at the git root
  Fix: bash tools/restructure_repo.sh

GET /repos/AbdElrhmanAhmed7/FastAPI-v15/actions/workflows → {"total_count": 0, "workflows": []}
GET /repos/AbdElrhmanAhmed7/FastAPI-v15/actions/runs      → {"total_count": 0, "workflow_runs": []}
```

**Zero workflows.** GitHub did not fail a run — it never saw a workflow to run, because
`.github/workflows/backend.yml` was at `Final/.github/workflows/backend.yml`. The same
query on `Final-v14.5` returns one `active` workflow and one green run: that is the
control which proves the difference is the layout, not the workflow file.

### The fix

```bash
bash tools/restructure_repo.sh   # every move is a git mv, so history follows the files
bash tools/check_layout.sh       # ✓ layout ok
```

`.scratch/` was removed (workspace scratch); its useful half is now
`tools/verify_delivery.sh`, which applies the patch to a throwaway clone and extracts
the zip, so a delivery is tested instead of assumed.

| # | Repository / commit | Wrapper on arrival | CI |
| --- | --- | --- | --- |
| 1 | first delivery | `NOVA/` | never ran |
| 2 | second delivery | `repo/` | never ran |
| 3 | third delivery | `upstream/` | never ran |
| 4 | English pass | `repo/` (`novaa/`) | never ran |
| 5 | `Final` · `11cefe5` | `repo/` | never ran |
| 6 | `NovaAPI-v14` · `24dc3e6` | none | 3/3 jobs green |
| 7 | `Final-v14.5` · `bbfa863` | none | 3/3 jobs green |
| 8 | **`FastAPI-v15` · `5ee0295`** | **`Final/` (the workspace folder)** | **0 workflows discovered** |

### Two rules this delivery adds

1. **Upload the repository, not the workspace.** If your project lives in
   `…/workspace/Final`, upload the *contents of `Final`* — not `workspace`, and not
   `Final` itself. Anything beside the repo (scratch scripts, notes, downloads) is
   otherwise committed with it.
2. **A patch is only valid against the commit that is on GitHub.** This history was
   squashed again, so `24dc3e6`, `bbfa863` and `fd73e5a` are all gone and the committed
   patch could not be applied. Regenerate above the real baseline, then prove it:

```bash
bash tools/make_release.sh   --base 5ee0295
bash tools/verify_delivery.sh --base 5ee0295
```

### Keep it this way

```bash
git clone https://github.com/AbdElrhmanAhmed7/FastAPI-v15 && cd FastAPI-v15
git am /path/to/releases/nova-backend-final.patch
bash tools/check_layout.sh        # ✓ layout ok
git push origin main
```

Then open the **Actions** tab: a workflow named `backend` must appear with 3 jobs. If
the tab is empty, GitHub still cannot see the workflow — run the guard, and
`tools/restructure_repo.sh` if it fails.

## 13. Ninth delivery: `FastAPI-v15.5` — the wrapper was the workspace itself (2026-11-13)

**Repo: `AbdElrhmanAhmed7/FastAPI-v15.5`** · commit `c36ff13` (`v15.5`) · 246 tracked files

The seventh occurrence, and the one that identified the cause. The uploaded root was:

```
<git root>/
├── Final/            ← .github/, NOVA/, tools/, … (245 files)
└── HANDOVER-v15.md
```

Compare that with the assistant workspace at the end of the previous session:

```
<workspace root>/
├── .arena/           ← platform directory, not persisted
├── Final/            ← the git repository
├── HANDOVER-v15.md   ← the handover note
└── uploads/          ← upload scratch
```

They match. The user uploaded **the contents of the workspace**, which is exactly what
the previous instructions asked for. The repository happened to live in `Final/`, so
the contents included `Final/`. The eighth delivery has the same fingerprint — its root
carried `.scratch/`, which only ever existed in the workspace.

**The wrapper was produced by the workspace layout, not by the upload.** Six wrappers
were diagnosed as an upload mistake; the last two were not.

### Measured, not inferred

```
$ bash tools/check_layout.sh
✗ NOVA/backend is not at the git root
  Fix: bash tools/restructure_repo.sh

GET /repos/AbdElrhmanAhmed7/FastAPI-v15.5/actions/workflows → {"total_count": 0, "workflows": []}
GET /repos/AbdElrhmanAhmed7/FastAPI-v15.5/actions/runs      → {"total_count": 0, "workflow_runs": []}
```

Zero workflows, zero runs. The control (`Final-v14.5`, same workflow file at the correct
depth) returns one `active` workflow and 3/3 green jobs.

### The fix: make the two roots the same directory

```bash
bash tools/restructure_repo.sh   # git mv Final/* to the git root; history follows
bash tools/check_layout.sh       # ✓ layout ok
```

and, structurally, the repository is now checked out **at the workspace root**:

```
<workspace root> == <git root>
├── .github/workflows/backend.yml
├── NOVA/  tools/  verification/  releases/  reference/
└── .gitignore   →  /uploads/  /.arena/  ignored
```

Uploading the workspace contents now lands `.github/` at the git root. The action that
used to create the wrapper is now the action that produces a correct repository — so
the failure mode is gone, not merely documented.

The Arabic handover note is no longer written into the workspace at all:
`test_english_content.py` scans every text file in the tree, so an Arabic document at
the root fails the language gate. It is delivered in the conversation.

| # | Repository / commit | Wrapper on arrival | CI | Cause |
| --- | --- | --- | --- | --- |
| 1 | first delivery | `NOVA/` | never ran | release zip prefix |
| 2 | second delivery | `repo/` | never ran | upload folder |
| 3 | third delivery | `upstream/` | never ran | upload folder |
| 4 | English pass | `repo/` (`novaa/`) | never ran | upload folder |
| 5 | `Final` · `11cefe5` | `repo/` | never ran | upload folder |
| 6 | `NovaAPI-v14` · `24dc3e6` | none | 3/3 jobs green | — |
| 7 | `Final-v14.5` · `bbfa863` | none | 3/3 jobs green | — |
| 8 | `FastAPI-v15` · `5ee0295` | `Final/` | 0 workflows discovered | **workspace layout** |
| 9 | **`FastAPI-v15.5` · `c36ff13`** | **`Final/`** | **0 workflows discovered** | **workspace layout — now removed** |

### The rule this delivery replaces

§12 said *upload the repository, not the workspace*. That is still true advice for
anyone dragging folders, but it was not the cause here. The rule that actually holds:

> **Keep the repository at the root of whatever directory gets uploaded.** If the
> upload unit is the workspace, the git root must be the workspace root. Detection
> (`check_layout.sh`) is the safety net; layout is the fix.

### Keep it this way

```bash
git clone https://github.com/FastAPI-v15.5 && cd FastAPI-v15.5
git am /path/to/releases/nova-backend-final.patch
bash tools/check_layout.sh          # ✓ layout ok
bash tools/make_release.sh   --base c36ff13
bash tools/verify_delivery.sh --base c36ff13
git push origin main
```

Then open the **Actions** tab: a workflow named `backend` must appear with 3 jobs. If
the tab is empty, GitHub still cannot see the workflow — run the guard, and
`tools/restructure_repo.sh` if it fails.
