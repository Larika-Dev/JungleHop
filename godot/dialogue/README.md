# Dialogue: 30 personalities, choice-based conversations

Autoload: `Dialogue="*res://dialogue/dialogue.gd"` (add under `[autoload]` in `godot/project.godot`).

## Data
- `data/personalities.json`: 30 personalities with Life trait vectors (`outgoing, kind, ambitious, wild, lawful`), interests and population weight.
- `src/<id>.txt`: hand-written lines. Each personality has 100-200 **base** lines, 50+ **dating** lines, 200+ **marriage** lines.
- `tools/build_dialogue.py` compiles `src/` to `data/lines/<id>.json` and fails on missing counts, unknown tokens, or a line reused across personalities. Run it after editing `src/`.
- `data/conversation.json`: the player's choices (labels, which NPC context answers, which Life action runs).

Lines are filtered by friendship tier (`stage`), romance tier, time of day (morning 5-12, afternoon 12-17, evening 17-22, night 22-5), weekend and place tags. Tokens: `{player}`, `{npc}`, `{place}`, `{weekday}`, `{timeofday}`.

## API for the NPC thread
```gdscript
var pid := Dialogue.assign_personality(npc_id, traits)   # deterministic per npc_id; traits optional
Dialogue.set_personality(npc_id, "dry_cynic")            # force (saved via Life save provider)
Life.relationships.register_npc(npc_id, Dialogue.npc_info(npc_id))  # traits + interests
Dialogue.set_npc_name(npc_id, "Jordan")
```
Single lines: `Dialogue.get_line(npc, context, extra)`, `Dialogue.say(npc, context)` (emits `line_spoken`).

## Conversations (how talking works)
Every turn the player picks from **4 to 6 options**; yes/no prompts (an NPC asking a favor) show exactly 2. The NPC answers in its personality's voice. Options change with the relationship: dating unlocks date talk, kiss, propose; marriage unlocks home talk, chores, money, dinner, support, plans, memories, bedtime and more.

```gdscript
Dialogue.open_conversation(npc_node)          # built-in panel: click or press 1-9
# or drive your own UI:
var st := Dialogue.start_conversation(npc, {"has_gift": true})
# st = {npc_line, npc_followup, options: [{id, label, kind}], pending, ended}
st = Dialogue.choose(npc, st.options[0].id)
```
If Life registers the mapped action (`chat`, `compliment`, `flirt`, `ask_on_date`, `kiss`, `propose`...), choosing runs it for relationship effects; yes/no questions (ask out, propose) wait for Life's `action_finished` result. Without Life they fall back to romance thresholds.

## Tests
`godot --headless --path godot -s res://dialogue/tests/run_tests.gd`
