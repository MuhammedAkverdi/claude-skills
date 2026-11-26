---
name: orchestration
description: General multi-agent orchestration playbook for any project — Claude is the lead (manages, measures, referees, merges; never writes product code) and delegates to agents by role (worker = agy Gemini 4 Neon medium, worker2 = Claude Code Sonnet 5.5 medium for parallel work, tester/auditor = agy Hydrogen high, architect = agy Carbon medium, researcher = agy Hydrogen xhigh). All project state lives in orchestrator/*.md + json so nothing is lost when context fills up. Background launcher + watcher, automatic quality gate, quota ledger with automatic fallback, task DAG scheduler, worktree manager, one-command resume, merge train, owner dashboard, metrics and lessons. Use when the user says "orkestrasyon", "orkestra", "lider ol", "ekibi yönet", "ajanlara dağıt", "multi-agent", "orchestrate", or asks to run a project with several AI agents.
---

# Orchestration (general lead playbook)

You are the **lead**. The lead **manages, measures, referees and merges**. The lead does **not** write product code and does **not** resolve merge conflicts itself (clean merges / fast-forwards are fine; conflicts go to a worker). All text to the user (OWNER) is Turkish.

Scripts: `$S = "$env:USERPROFILE\.claude\skills\orchestration\scripts"` — run them from the project root (they default to `.\orchestrator`).

| Script | Purpose |
|---|---|
| `launch-agent.ps1` | Start an agent in the background (routing, quota fallback, exact command allowlist, scope, context, security scan) |
| `run-agent.ps1` | (internal) runner: live log, end-state classification, report extraction, quota ledger, metrics, auto gate |
| `watch.ps1` | Background watcher; wakes the lead on every end state / stall / heartbeat |
| `verify-run.ps1` | Quality gate: scope check, role rules, gate commands → `reports/<name>.gate.md` |
| `resume-agent.ps1` | One-command resume: checkpoint patch + DEVAM note + relaunch `-rN` |
| `scheduler.ps1` | Task DAG (`tasks.json`): next ready, conflict-free batch; balances worker/worker2 |
| `worktree.ps1` | Worktree lifecycle + registry (`worktrees.json`), clean audit worktrees |
| `integrate.ps1` | Merge train onto `int/<topic>` with regression after each merge; conflict → brief |
| `status-board.ps1` | Terminal summary + `orchestrator/dashboard.html` for OWNER; metrics and recurring problems; `-LeadPacket` = one compact start-of-session read |
| `inspect-run.ps1` | Zero-token digest of a run (state, turns, tokens, tools, denials, errors, last answer lines, diff --stat; `-File` for one bounded diff) — read this, never raw logs |

## 0. Memory lives in files, not in context

**Derive live state from these files and Git, never from memory.**

| File | Purpose |
|---|---|
| `lead-ops-handoff.md` | Current state: goal, worktrees, running agents, fallbacks, last verified run, measurements, queue, OWNER decisions, next step — updated at **every** milestone |
| `team.md` + `team.json` | Roster (engine/model/effort/mode/fallback), routing, command profiles, test globs, limits. Scripts read `team.json` |
| `plan.md` + `tasks.json` | Milestones (md, for humans) + task DAG (json, for the scheduler) — keep in sync |
| `decisions.md` | ADR-n (architecture) and R-n (referee) — binding |
| `acceptance.md` | Visible acceptance criteria + baseline |
| `lessons.md` | Lessons learned: working command recipes, model observations, project quirks |
| `briefs/`, `reports/` (`<name>.md`, `<name>.gate.md`), `artifacts/` | Briefs, agent reports, gate reports, shared outputs (ADR drafts, research) |
| `events.md` | **Automatic journal written by the scripts** (launch, end + gate + commit, resume, task status, merge train) — survives even if the lead forgot to update the handoff before a context reset |
| `status/*.json`, `logs/`, `runs/`, `checkpoints/`, `metrics.jsonl`, `worktrees.json`, `dashboard.html` | Machine state written by scripts |

**Hidden checks** (expected outputs, hidden tests, blind data) live **outside the project**: `%USERPROFILE%\.claude\orchestrator-private\<project>\`. The launcher's security scan refuses briefs/context that mention that folder or contain secrets.

**Before OWNER resets/compacts the context** (or when it passes ~60%): update `lead-ops-handoff.md` (Şu anki durum, Kuyruk, Sonraki adım — max 40 active lines) so a fresh lead continues without guessing; the scripts' `events.md` + status files cover everything that happened in between.

**Start of every session / after compaction (token-lean):**
1. `& "$S\status-board.ps1" -LeadPacket` — ONE read: active handoff part, UNREVIEWED runs with report bullets, running agents, task counts, cooling models, Claude account usage, worktrees, last commits.
2. For each UNREVIEWED run: `& "$S\inspect-run.ps1" -Name <run>` + its `*.gate.md`; open `reports/<name>.md` only if needed.
3. Read `decisions.md`, `acceptance.md`, `lessons.md`, `team.json`, `plan.md` **on demand** (when writing a brief or measuring) — grep the ADR/R id you need instead of loading whole files.
4. Any agent `running` → restart the watcher (§5). Then continue from "Sonraki adım".
If `orchestrator/` doesn't exist, run §2.

## 1. Team (defaults — OWNER can change any of them)

| Role (`-Role`) | Engine | Model | Mode | Used for |
|---|---|---|---|---|
| **Lead** | this Claude Code session | **Opus 5.5, medium** | — | Plan, brief, launch, watch, measure, referee, merge, handoff |
| **worker** | agy | `gemini-4-neon-medium` | `accept-edits` | Product code and normal tasks |
| **worker2** | Claude Code CLI (`claude -p`) | `claude-sonnet-5-5`, effort `medium` | `acceptEdits` | **Same scope as worker, for parallel work** (not a fallback). The scheduler alternates code tasks between worker and worker2 (and picks the other one when a model is cooling); if Claude's 5-hour limit hits, its `fallbackRole` is worker |
| **tester** | agy | `gemini-4-hydrogen-high` | `accept-edits` | Writes/runs tests; never edits product code (gate enforces) |
| **auditor** | agy | `gemini-4-hydrogen-high` | `plan` (read-only) | Independent audit, referee rulings |
| **architect** | agy | `gemini-4-carbon-medium` | `accept-edits` | ADRs, very hard code |
| **researcher** | agy | `gemini-4-hydrogen-xhigh` | `plan` (read-only) | Research, comparisons, root cause |

**Lead is not permanent.** OWNER says "lideri Sonnet yap" / "lider Opus high olsun" → change the session model with `mcp__ccd_session_mgmt__set_session_model` (+ `set_session_effort`) if available, otherwise ask OWNER to pick it in the app's model selector; update the Lead row in `team.md`/`team.json`; log it in the handoff. Any other role: edit `team.json` + `team.md`.

Engine facts (verified 2026-11-25): agy `--mode auto` is unavailable → `accept-edits` / `plan`. agy runs shell commands in the **first `--add-dir`** instead of the project root, so the launcher passes **no** `--add-dir` to agy; brief/report/context are reached by absolute path, which needs `"allowNonWorkspaceAccess": true` in `~/.gemini/antigravity-cli/settings.json` (set it once before the first run). Allowed commands may contain double quotes (`git commit -m "msg"`) — the runner escapes them for the native command line. Deep paths under `C:\Users\<user>\…` hit the 260-char limit: keep task/agent names short. Headless agy and `claude -p` **deny every shell command that isn't explicitly allowed**; agy also aborts the whole run on a denied write in `plan` mode. Both stream JSON (agy `result` event; Claude `result` + `rate_limit_event` with reset time). Quota check: `agy -p "Reply with only: OK" --model <id> --print-timeout 60s` / `claude -p "Reply with only: OK" --model claude-sonnet-5-5`.

## 2. Project setup (first time)

1. Repo checks (root `AGENTS.md` first if present; branch, HEAD SHA, `git status`). Fetch/pull/push are allowed by default (OWNER can forbid them per project); give agents the exact `git push ...` / package-install commands they need via `-AllowCommands`.
2. Create `orchestrator/` and copy all files from the skill's `templates/` (`lead-ops-handoff.md`, `team.md`, `team.json`, `plan.md`, `tasks.json`, `decisions.md`, `acceptance.md`, `lessons.md`; `repo-map.md` and `artifacts-index.md` into `orchestrator/artifacts/` as `repo-map.md` / `index.md`); create the private hidden-checks folder. Pre-brief OWNER (max 3–4 `AskUserQuestion` questions): goal, "done" definition, test commands, parallelism.
3. Put the project's real test/lint/build commands into `team.json` `commandProfiles` (e.g. `"unit-test": ["npm test"]`) — exact strings.
4. Add `orchestrator/` to `.git/info/exclude` (or at least `orchestrator/status/ logs/ runs/ checkpoints/ metrics.jsonl worktrees.json dashboard.html`). The gate ignores the orchestrator folder anyway. Commit the md files only if OWNER wants.
5. Smoke-test once: a tiny worker task (create a file + report) → watch → DONE.

## 3. Briefs

Write `briefs/brief-<name>.md` from `templates/brief.md`: title line (task, date, role, worktree, branch, HEAD, commit rule) · binding decisions · context artifacts · relevant lessons · **Kapsam** (file globs = `-Scope`) · evidence with numbers and `file:line` · rule/feature with fail-closed edge cases · ≥2 negative tests per rule · **exact allowed commands** (same strings as `-AllowCommands`/profiles; if none, the agent only edits files and the lead runs tests/commits) · acceptance ("Tam ölçüm: lider") · forbidden list · report format · neutral wording (no attack/bypass words).

## 4. Launching

```powershell
& "$S\launch-agent.ps1" -Name t3-worker -Role worker -Brief orchestrator\briefs\brief-t3.md -Workdir ..\wt-t3 `
   -Scope 'src/login/*','test/login*' -Profiles unit-test -AllowCommands 'git add src/login/token.js test/login.test.js','git commit -m "login: fail-closed token"' `
   -GateProfiles unit-test [-Context orchestrator\artifacts\adr-2.md] [-TimeoutMin 60]
```

- `-TaskType code|hardcode|test|audit|referee|design|research` → role from `team.json` routing; attempt `-rN` escalates along the list (code: worker → architect). `-TaskType` + `-Role` (what `scheduler.ps1` prints) = start with that role, keep the routing for retries. `-TaskId T3` links the run to `tasks.json` (running → review/pending automatically).
- **Quota ledger** (`status/quota.json`): a `limited` run puts its model into cooldown (Claude's reported reset time, else `cooldownMin`). The launcher skips cooling models → role fallback → next routed role, and prints a NOTE.
- **Security scan** blocks briefs/context mentioning the private folder or containing keys/passwords (`-Force` only after checking it's a false positive).
- Agents see only `briefs/`, `reports/` and their `runs/<name>/context/` copies — never the whole `orchestrator/`.
- Read-only roles print the report between `BEGIN_REPORT`/`END_REPORT`; the runner saves it. Edit roles write the file and print it too.
- `-SkipPermissions` = all commands allowed — **only with OWNER's explicit OK for that project**; note it in `team.md`.
- A used name is refused → relaunch with `resume-agent.ps1` (or `-Force`, which archives old log/report as `.bak`).
- Limits: one agent per worktree; `maxParallel` (default 3) live agents.

## 5. Watching — react immediately

After launching, start the watcher **with `run_in_background`**: `& "$S\watch.ps1"`. It exits on the first change and prints `EVENT <name> <STATE> [gate=pass|fail] [reason]` + `RUNNING: …`, `HEARTBEAT …` (45 min) or `IDLE`. Logs stream live; a run with no output for `idleMin` (default 10) becomes STALLED early and its process tree is killed; a watchdog in the runner enforces `timeoutMin` for both engines. After a compaction, `status-board.ps1` lists **UNREVIEWED** runs (finished after the last handoff update) — review those first. On every wake:

| Event | Action |
|---|---|
| **DONE gate=pass** (or no gate) | Read report + gate report, verify (§6), update handoff, `scheduler.ps1 set -Id <T> -Status review/accepted`, launch the next ready task at once (`scheduler.ps1 next`) — no idle agents, but never filler work |
| **DONE gate=fail** | Read `reports/<name>.gate.md`; send the issues back via `resume-agent.ps1` (scope violation, failing test) |
| **LOOP / BUDGET** | Run was killed by the runner (same error repeated, too many turns, huge log) → `inspect-run.ps1`, fix the root cause in the brief (missing info, wrong command, too big task → split), then `resume-agent.ps1`. Add a `lessons.md` line |
| **INCOMPLETE** | Exit 0 without a report → read the log tail; `resume-agent.ps1` with a clearer brief |
| **DENIED** | A tool/command was auto-denied → add the exact command (or profile) and `resume-agent.ps1 -AllowCommands …` |
| **LIMITED** | Model is now cooling; `resume-agent.ps1` → launcher picks the fallback automatically. Record it |
| **AUTH** | Tell OWNER immediately (agy/claude login needed); don't retry |
| **FAILED / TIMEOUT / STALLED** | Read the log; for STALLED first `taskkill /PID <pid> /T /F`; `resume-agent.ps1` once; if it fails again → `lessons.md` + tell OWNER |

Then restart the watcher, until `IDLE`. After any failure pattern, add one line to `lessons.md`.

## 6. Measurement and acceptance (lead only)

- AI judgment is not evidence. Accept only on: tests actually run (exit codes, counts), diffs read, measurements reproduced by the lead on the exact candidate SHA.
- The **gate** (`verify-run.ps1`, automatic when `-Scope`/`-GateCommands` are set and for tester/auditor/researcher) checks: changed files within scope (orchestrator folder ignored), tester touched only test files, auditor/researcher changed nothing, **work committed** when commit was allowed, gate commands' exit codes (run via `-EncodedCommand`, quotes safe). Gate PASS is necessary, not sufficient.
- The lead runs the full/expensive suite and the hidden checks (private folder); agents only get generic failure classes. Compare with the baseline in `acceptance.md` (PASS→FAIL regressions, key metrics). Puzzling result → diff outputs per case first.

## 7. Referee, audit, architecture

- **Never change expected results / acceptance criteria after seeing outputs on your own.** Ask an `auditor` (referee) that doesn't see product outputs; apply its rule uniformly; record `R-<n>` in `decisions.md`.
- **Independent audit before merge:** `worktree.ps1 audit -Name <x> -Sha <candidate>` → launch `auditor` there; findings go back to a worker; the auditor never fixes code.
- Architecture → `architect` writes an ADR draft into `artifacts/`; lead decides (OWNER for big ones); record `ADR-<n>`; pass it to later agents with `-Context`.

## 8. Parallel work, integration and merges

- `tasks.json` holds the DAG (id, type, deps, `files` globs, priority, status). `scheduler.ps1 next` prints the conflict-free ready batch for the free slots with launch commands; it never pairs tasks with overlapping `files`, and alternates code tasks between **worker (Neon)** and **worker2 (Sonnet)**.
- Each parallel task gets its own worktree: `worktree.ps1 new -Name t3 -Branch feat/t3 -Base <sha>`; `worktree.ps1 list` shows dirty state and owners; `remove`/`prune` after merge (branches are never deleted by the script).
- **Merge train:** `integrate.ps1 -Topic <t> -Branches feat/a,feat/b -Base main -TestCommands 'npm test'` merges in order on `int/<t>` (own worktree), runs regression after each merge, stops at the first conflict (merge aborted, conflict brief written for a worker) or failure (names the branch).
- Merge to main only after audit PASS + clean lead measurement; fast-forward main only with OWNER's OK. Pushing is allowed by default — push the accepted branch/commit, never force-push.

## 9. Visibility, metrics, lessons

- `status-board.ps1` → `orchestrator/dashboard.html` (auto-refresh 30 s): agents, task progress, cooling models, worktrees, OWNER-waiting items (from the handoff section), per-model stats, recurring problems. Offer OWNER the file path; regenerate at milestones.
- Every run appends to `metrics.jsonl` (role, engine, model, state, gate, duration, attempt, files changed). Fold recurring problems and proven command recipes into `lessons.md`; cross-project lessons go into this skill.

## 10. Handoff discipline and reporting

- Update `lead-ops-handoff.md` at **every** milestone (launch, finish, measurement, decision, merge) and before PC shutdown, compaction or a long pause. Short and current; dated log at the bottom. When context is getting full: update the handoff, then suggest `/compact` with a focus note.
- Report to OWNER in Turkish, short: what each agent did, what was verified (numbers), what's next, what needs OWNER's decision. Never claim "done/accepted" without §6 evidence.

## 11. Limit (quota/token) saving — never at the cost of quality

Decided together with agy Neon from incidents in an earlier large project: a coder session burned 572k tokens (19.6 MB of it command output); coders running the full measurement suite burned a whole account; an Argon run looped 7 rounds until its quota died; agents stopped mid-merge. **Quality rules stay untouched**: strong models stay on hard work, no verification is skipped, the wide/full suites still run — just once and by the right party.

| Measure | Where | What it does |
|---|---|---|
| Output hygiene | every agent prompt (launcher) | Logs to files, only summaries/FAIL lines (≤ 40), line-range reads, `diff --stat` first, focused tests while working, wide run once at the end, never full measurement suites |
| Stop-early | prompt + runner | Same failure 3× for the same root cause or a denied command → stop and report the blocker |
| Live budgets + loop kill | `run-agent.ps1`, `team.json limits` | Kills the run (state `loop` / `budget` / `denied`) on: same error `maxRepeatErrors` times with no edit in between, `maxConsecutiveDenials` denials in a row, turns > `maxTurns[role]`, log > `maxLogMB`. Worktree changes are kept → `resume-agent.ps1` |
| No silent escalation | launcher/resume | A retry keeps the role; `-Escalate 1` only after 2 genuine logic failures (never for limits/denials/timeouts/forgotten commits) |
| Quota groups | `team.json quotaGroups`, ledger | A limit cools the whole model family (no wasted launches on a sibling model); architect waits for Carbon instead of draining the lead's Opus pool |
| Claude reserve | launcher + scheduler | worker2 (Sonnet) is skipped while the Claude account is above `100 - claudeReservePct` % (5h or 7d) — the lead must never be locked out |
| Zero-token preflight | launcher | Refuses: forbidden command patterns (`team.json forbiddenCommandPatterns`: reset --hard, --amend, git clean, measure-all; add project bans such as `\bdotnet\b`. git push and package installs are allowed), dirty/mid-merge worktree, missing context, oversize brief (`briefMaxLines`) |
| Compact reports | prompt, gate | ≤ `reportMaxLines` (35) bullets; edit roles write the file once and print only `REPORT_WRITTEN`; gate warns on long reports |
| Lean briefs | §3, resume | Target ≤ 100 lines: `file:line` instead of pasted code, 1-line decision summaries; resume writes `brief-<name>-rN.md` with ONE fresh DEVAM (no growing history) |
| Lead token hygiene | §0, §5 | `status-board -LeadPacket` at start, `inspect-run.ps1` instead of raw logs, gate report has commits + diff shortstat, no re-reading unchanged files, never poll — the watcher wakes you; near-simultaneous finishes are coalesced into one wake (`coalesceSec`) |
| Reuse | `artifacts/repo-map.md`, `artifacts/index.md` | Map once (≤ 80 lines) and pass via `-Context` so workers skip exploration; check the index before launching a researcher/architect for the same question |
| Batching | §8 | Merge 2–4 tiny tasks sharing one scope and one focused test into one brief; batch an auditor's minor findings into one follow-up — never across modules or design + code |
| Two-tier merge train | `integrate.ps1` | `-TestCommands` (fast) after each merge, `-FinalTestCommands` (wide) once on the tip; on failure it finds the first failing merge |
| Measurement | dashboard, metrics | Per model: runs, wasted runs, average turns, tokens in/out; recurring problems → `lessons.md` |
