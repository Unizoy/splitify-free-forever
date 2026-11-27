-- 0027 Deleted targets (final QA for D-034, S-406): a bell row or push about a deleted expense or payment
-- opened the group page; it now opens the expense / payment page, which shows "Deleted" and Restore (D-034 A4,
-- B2). private.notification_content is 0026's body with only the two `<> '..._deleted'` conditions removed;
-- rows already in the bell for such deletes get the same target (the phone sees them on its next full fetch).

create or replace function private.notification_content(a public.activity, p_member uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  g record;
  d jsonb := a.data;
  v_actor text;
  v_amount text;
  v_desc text;
  v_body text;
  v_title text;
  v_from uuid;
  v_to uuid;
  v_target_type text := 'group';
  v_target uuid := a.group_id;
  v_snippet text;
begin
  select gg.name, gg.type, gg.main_currency::text as main_currency into g
  from public.groups gg where gg.id = a.group_id;
  v_actor := coalesce(private.member_name(a.actor_member_id),
                      (select nullif(btrim(p.display_name), '') from public.profiles p where p.id = a.actor_user_id),
                      'Someone');
  v_amount := case
    when jsonb_typeof(d -> 'total') = 'number' then private.format_money((d ->> 'total')::bigint, d ->> 'currency')
    when jsonb_typeof(d -> 'amount') = 'number' then private.format_money((d ->> 'amount')::bigint, d ->> 'currency')
  end;
  v_desc := '“' || coalesce(nullif(d ->> 'description', ''), 'an expense') || '”';

  if a.type like 'expense_%' then
    v_body := case
      when a.type = 'expense_added' and coalesce(d ->> 'recurring', '') = 'true'
        then v_desc || ' was added (recurring)'
      when a.type = 'expense_added' then v_actor || ' added ' || v_desc
      when a.type = 'expense_edited' then v_actor || ' edited ' || v_desc
      when a.type = 'expense_deleted' then v_actor || ' deleted ' || v_desc
      else v_actor || ' restored ' || v_desc
    end || coalesce(' · ' || v_amount, '');
    -- 0027: a deleted expense opens its own page too (Deleted + Restore), not the group.
    v_target_type := 'expense';
    v_target := a.target_id;
  elsif a.type like 'payment_%' then
    v_from := private.try_uuid(d ->> 'from_member');
    v_to := private.try_uuid(d ->> 'to_member');
    v_body := case
      when a.type = 'payment_added' and p_member = v_to and a.actor_member_id = v_from
        then v_actor || ' paid you ' || coalesce(v_amount, '')
      when a.type = 'payment_added' and p_member = v_to
        then v_actor || ' recorded that ' || coalesce(private.member_name(v_from), 'someone') || ' paid you '
             || coalesce(v_amount, '')
      when a.type = 'payment_added' and p_member = v_from and a.actor_member_id = v_to
        then v_actor || ' recorded your payment of ' || coalesce(v_amount, '')
      when a.type = 'payment_added' and p_member = v_from
        then v_actor || ' recorded that you paid ' || coalesce(private.member_name(v_to), 'someone') || ' '
             || coalesce(v_amount, '')
      when a.type = 'payment_added' then v_actor || ' recorded a payment' || coalesce(' · ' || v_amount, '')
      when a.type = 'payment_edited' then v_actor || ' edited a payment' || coalesce(' · ' || v_amount, '')
      when a.type = 'payment_deleted' then v_actor || ' deleted a payment' || coalesce(' · ' || v_amount, '')
      else v_actor || ' restored a payment' || coalesce(' · ' || v_amount, '')
    end;
    -- 0027: a deleted payment opens its own page too (Deleted + Restore), not the group.
    v_target_type := 'payment';
    v_target := a.target_id;
  elsif a.type = 'reminder_sent' then
    -- 08 #23 copy: "Mohit reminded you about ₹500 in “Goa trip”".
    v_body := v_actor || ' reminded you about '
      || coalesce(private.format_amounts(d -> 'amounts', g.main_currency), v_amount, 'what you owe')
      || case when g.type = 'direct' then '' else ' in “' || g.name || '”' end;
    v_target_type := 'balances';
  elsif a.type = 'settle_nudge' then
    -- 0026: "Time to settle up: you owe ₹200 · you're owed $10" (D-034 C4), the reader's own balance.
    v_body := case when d ->> 'reason' = 'trip_end' then 'Your trip is over. Time to settle up: '
                   else 'Time to settle up: ' end
      || coalesce(private.balance_words(a.group_id, p_member, g.main_currency), 'see who owes whom');
    v_target_type := 'balances';
  elsif a.type = 'whiteboard_updated' then
    v_body := v_actor || ' updated the group notes';
  elsif a.type = 'comment_added' then
    select left(regexp_replace(btrim(c.body), '\s+', ' ', 'g'), 80)
           || case when char_length(btrim(c.body)) > 80 then '…' else '' end
    into v_snippet
    from public.comments c where c.id = a.target_id;
    if d ->> 'target_type' = 'expense' then
      select '“' || e.description || '”' into v_desc from public.expenses e
      where e.id = private.try_uuid(d ->> 'target_id');
      v_body := v_actor || ' commented on ' || coalesce(v_desc, 'an expense');
    else
      v_body := v_actor || ' commented on a payment';
    end if;
    v_body := v_body || coalesce(': “' || v_snippet || '”', '');
    if d ->> 'target_type' in ('expense', 'payment') and private.try_uuid(d ->> 'target_id') is not null then
      v_target_type := d ->> 'target_type';
      v_target := private.try_uuid(d ->> 'target_id');
    end if;
  elsif a.type = 'member_joined' then
    v_body := v_actor || ' joined the group';
  elsif a.type = 'member_claimed' then
    v_body := v_actor || ' joined the group as ' || coalesce(d ->> 'name', 'a member');
  elsif a.type = 'member_left' then
    v_body := coalesce(private.member_name(a.target_id), v_actor) || ' left the group';
  elsif a.type = 'member_removed' then
    v_body := case when p_member = a.target_id then v_actor || ' removed you from the group'
                   else v_actor || ' removed ' || coalesce(d ->> 'name', 'a member') || ' from the group' end;
  else
    v_body := case
      when d ->> 'setting' = 'simplify_debts' and d ->> 'simplify_debts' = 'true'
        then v_actor || ' turned on simplify debts'
      when d ->> 'setting' = 'simplify_debts' then v_actor || ' turned off simplify debts'
      when d ->> 'setting' = 'default_split' then v_actor || ' changed the default split'
      when d ->> 'setting' = 'settle_reminder' and d ->> 'settle_reminder' in ('weekly', 'monthly')
        then v_actor || ' turned on ' || (d ->> 'settle_reminder') || ' settle-up reminders'
      when d ->> 'setting' = 'settle_reminder' then v_actor || ' turned off settle-up reminders'
      else v_actor || ' changed the group settings'
    end;
  end if;

  v_title := case when a.type = 'settle_nudge' and g.type = 'direct' then 'Splitify'
                  when g.type = 'direct' then v_actor else coalesce(g.name, 'Splitify') end;
  return jsonb_build_object(
    'title', left(v_title, 200),
    'body', left(v_body, 600),
    'data', jsonb_build_object(
      'target_type', v_target_type, 'target_id', v_target, 'group_id', a.group_id,
      'actor_member_id', a.actor_member_id, 'actor_name', v_actor));
end;
$$;

update public.notifications n
set data = n.data || jsonb_build_object('target_type', a.target_type, 'target_id', a.target_id)
from public.activity a
where a.id = n.activity_id
  and a.type in ('expense_deleted', 'payment_deleted')
  and a.target_type in ('expense', 'payment')
  and a.target_id is not null
  and n.data ->> 'target_type' = 'group';
