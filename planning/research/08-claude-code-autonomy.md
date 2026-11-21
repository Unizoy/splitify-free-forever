# Research 08 — Running Claude Code sessions autonomously

Compiled 2026-11-21 from the official Claude Code docs (fetched by a research agent and then re-verified with
quotes). Doc URLs: permissions `https://code.claude.com/docs/en/permissions.md`, settings reference
`https://code.claude.com/docs/en/settings-reference.md`, permission modes
`https://code.claude.com/docs/en/permission-modes.md`, hooks `https://code.claude.com/docs/en/hooks.md`,
skills `https://code.claude.com/docs/en/skills.md`, sub-agents `https://code.claude.com/docs/en/sub-agents.md`,
MCP `https://code.claude.com/docs/en/mcp.md`, VS Code `https://code.claude.com/docs/en/vs-code.md`,
headless `https://code.claude.com/docs/en/headless.md`, memory `https://code.claude.com/docs/en/memory.md`.

Items marked **[CONFLICT]** were answered differently by the docs fetch and by evidence on this PC; the plan's
config is written so it works either way.

## 1. Permission modes

| Mode | Behaviour |
| --- | --- |
| `default` | Prompts for anything not pre-approved. |
| `acceptEdits` | Auto-approves file edits and common filesystem commands. |
| `plan` | Read-only exploration. |
| `auto` | A classifier approves most actions; still blocks risky ones (production deploys/migrations, force-push, `git reset --hard`, mass cloud deletion, `curl | bash`, writing to secret managers, sending sensitive data out). The owner's user settings already default to `auto`. |
| `dontAsk` | Only pre-approved tools run; everything else is denied without a prompt. |
| `bypassPermissions` | No prompts at all. **Deny rules and PreToolUse hooks still apply in every mode, including bypass** ("deny rules hold in every permission mode, including auto and bypassPermissions" — best-practices doc). |

How to turn bypass on without committing it (owner decision D-003):

- `.claude/settings.local.json` (git-ignored, this PC only):
  `{"permissions": {"defaultMode": "bypassPermissions"}, "skipDangerousModePermissionPrompt": true}`.
  `skipDangerousModePermissionPrompt` is valid only in user, local or managed settings — **not** in the
  committed project `.claude/settings.json`.
- VS Code extension: settings `claudeCode.initialPermissionMode: "bypassPermissions"` and
  `claudeCode.allowDangerouslySkipPermissions: true` (adds Bypass to the mode selector). Put them in the
  workspace file `.vscode/settings.json`, which this repo's `.gitignore` already ignores (`.vscode/*`).
- CLI alternative: `claude --permission-mode bypassPermissions` or `claude --dangerously-skip-permissions`.
- An org/managed setting `permissions.disableBypassPermissionsMode` can forbid bypass; not set on this PC.

## 2. Permission rules

- Rule forms: `Bash(git commit *)`, `Read(./.env)`, `Edit(path/**)`, `WebFetch(domain:example.com)`,
  MCP tools by exact name or prefix (`mcp__supabase__execute_sql`, `mcp__supabase__*`).
- Deny beats allow at every layer; managed settings cannot be overridden.
- Precedence (low → high): user `~/.claude/settings.json` → project `.claude/settings.json` →
  local `.claude/settings.local.json` → CLI args; managed settings always win.
- `"$defaults"` inside an `allow`/`deny` list keeps the built-in auto-mode rules instead of replacing them.
- **[CONFLICT] PowerShell rules.** The docs fetch found no separate `PowerShell(...)` rule type, but the owner's
  working user settings contain `PowerShell(git status:*)` rules and this environment exposes a separate
  `PowerShell` tool. Plan config therefore writes every deny rule in **both** forms (`Bash(...)` and
  `PowerShell(...)`) and the guard hook matches both tool names (`Bash|PowerShell`). The hook — not the rules —
  is the real enforcement.

## 3. Hooks

- Config lives under `"hooks"` in settings. Each entry: `matcher` (tool-name regex, e.g. `Bash|PowerShell`,
  `mcp__supabase__.*`), then `hooks: [{type: "command", command, args?, timeout?}]`.
- **Exec form** (with `args`): `command` is an executable on PATH, `args` passed literally — use
  `"command": "powershell.exe", "args": ["-NoProfile","-ExecutionPolicy","Bypass","-File","<script>"]`
  (the owner's user settings already use exactly this form for notifications).
  **Shell form** (no `args`): the string runs through PowerShell on Windows.
- Hook input arrives as JSON on stdin: `session_id`, `cwd`, `permission_mode`, `hook_event_name`,
  `tool_name`, `tool_input` (e.g. `tool_input.command`). `CLAUDE_PROJECT_DIR` is available.
- **PreToolUse**: exit code `2` blocks the tool call and feeds stderr to Claude as the reason. Exit 0 allows.
  Works in bypass mode. This is the main safety mechanism for D-003.
- **Stop**: can keep Claude working (`{"decision":"block","reason":"..."}` on stdout, or exit 2). The docs
  fetch could not confirm the `stop_hook_active` input field, so any Stop hook must be loop-safe on its own
  (the plan uses a counter file). Claude Code force-ends a turn after 8 consecutive blocks
  (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises it).
- **SessionStart**: matchers `startup`, `resume`, `clear` (and `compact`). Text printed to stdout is added to
  the session context (long-standing documented behaviour; the 2026 fetch did not re-confirm the wording, so
  keep the output short and also make the skill read the files itself).

## 4. Skills

- Layout: `.claude/skills/<name>/SKILL.md` (+ optional `scripts/`, `references/` files next to it).
  Project skills are auto-discovered; Claude sees `name` + `description` at session start and loads the body
  when the task matches or when the user types `/<name>`.
- Frontmatter keys: `name`, `description`, `when_to_use`, `disable-model-invocation`, `user-invocable`,
  `allowed-tools` (e.g. `Bash(git *) Read`), `argument-hint`, `arguments`, `context: fork`, `agent`, `model`,
  `effort`, `shell` (`bash` | `powershell`).
- Keep each SKILL.md under ~500 lines; put long references in sibling files and point to them.
- Descriptions must say *what* and *when* in concrete trigger words ("execute the plan", "run the tests",
  "new migration") so auto-invocation is reliable.

## 5. Sub-agents

`.claude/agents/<name>.md` with frontmatter `name`, `description`, `tools`, `model`, `permissionMode`,
`maxTurns`, `skills`, `isolation: worktree`. Good for verbose work (test runs, log reading, parallel reviews);
skills are better for procedures. The plan uses skills for procedures and the built-in general-purpose agent
for parallel reviews.

## 6. MCP servers (Supabase)

- Add with `claude mcp add --transport http supabase "https://mcp.supabase.com/mcp?project_ref=<ref>&features=..."`
  (default *local* scope → stored in `~/.claude.json` for this project only, nothing committed). The project
  ref is therefore never written into the public repo.
- Authenticate once with `/mcp` in an interactive session; OAuth tokens persist in `~/.claude.json` and are
  reused by later sessions on the same PC (including headless `claude -p`).
- Project `.mcp.json` files would need approval (`enableAllProjectMcpServers` / `enabledMcpjsonServers` are
  **top-level** settings keys); the plan avoids `.mcp.json` entirely.
- `.mcp.json` supports `${VAR}` and `${VAR:-default}` expansion in `url` and `headers` (not used here).

## 7. Long autonomous work

- Give each session a checkable goal (tests, analyzer, gates), commit at task boundaries, keep a progress file
  the next session reads first, and stop at a clean boundary. Auto-compaction keeps the project CLAUDE.md.
- Headless option for the owner: `claude -p "execute the plan" --permission-mode bypassPermissions`
  (one phase per run, per D-002).

## 8. CLAUDE.md layering

User `~/.claude/CLAUDE.md` and project `CLAUDE.md` are **concatenated**, not overridden; if they conflict the
model may follow either. So the project CLAUDE.md must state the exception explicitly and narrowly
("in this repo, sessions executing `planning/` phases may commit and push the phase branch without asking;
never `main`"), and a memory note repeats it. Enforcement of the hard limits (no `main`, no force-push, no
secrets) is done by the PreToolUse hook, not by wording.
