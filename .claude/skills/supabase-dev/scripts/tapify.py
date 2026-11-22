# Turns a pgTAP file (supabase/tests/NNN_x.test.sql) into one script for MCP execute_sql, which returns only
# the last result set: drops leading comments, collects every top-level `select` into a temp table `tap`
# (granted to public so `set local role authenticated` can still write it) and ends with one string_agg row.
# Usage: python .claude/skills/supabase-dev/scripts/tapify.py supabase/tests/023_storage.test.sql <out.sql>
# Only a `select` that STARTS a statement is collected (an `insert … select` continuation is left alone), and the
# multi-column `select num_failed(), _get(…)` summary some files end with is dropped (phase 19).
import io, sys, re
src = io.open(sys.argv[1], encoding='utf-8').read().splitlines()
out = []
started = False
statement_open = False  # True while the previous code line did not end a statement
for line in src:
    if not started:
        if line.startswith('--') or not line.strip():
            continue
        started = True
    stripped = line.strip()
    if stripped == 'begin;':
        out.append('begin;')
        out.append('create temp table tap(t text);')
        out.append('grant all on tap to public;')
        statement_open = False
        continue
    if stripped == 'rollback;':
        out.append("select string_agg(t, E'\\n') from tap;")
        out.append('rollback;')
        statement_open = False
        continue
    if line.startswith('select num_failed()'):
        continue
    if line.startswith('select ') and not statement_open:
        line = 'insert into tap ' + line
    out.append(line)
    code = stripped.split('--', 1)[0].rstrip() if not stripped.startswith('--') else ''
    if code:
        statement_open = not code.endswith(';')
io.open(sys.argv[2], 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
