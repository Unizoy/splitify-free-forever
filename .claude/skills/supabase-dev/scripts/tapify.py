# Turns a pgTAP file (supabase/tests/NNN_x.test.sql) into one script for MCP execute_sql, which returns only
# the last result set: drops leading comments, collects every top-level `select` into a temp table `tap`
# (granted to public so `set local role authenticated` can still write it) and ends with one string_agg row.
# Usage: python .claude/skills/supabase-dev/scripts/tapify.py supabase/tests/023_storage.test.sql <out.sql>
import io, sys, re
src = io.open(sys.argv[1], encoding='utf-8').read().splitlines()
out = []
started = False
for line in src:
    if not started:
        if line.startswith('--') or not line.strip():
            continue
        started = True
    if line.strip() == 'begin;':
        out.append('begin;')
        out.append('create temp table tap(t text);')
        out.append('grant all on tap to public;')
        continue
    if line.strip() == 'rollback;':
        out.append("select string_agg(t, E'\\n') from tap;")
        out.append('rollback;')
        continue
    if line.startswith('select '):
        line = 'insert into tap ' + line
    out.append(line)
io.open(sys.argv[2], 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
