#!/usr/bin/env bash
SINK=$(wpctl status 2>/dev/null | grep -A1 "Filters" | grep "Audio/Sink" | grep -oP '\d+')
[ -z "$SINK" ] && SINK=$(pw-dump 2>/dev/null | python3 -c "
import sys,json
for o in json.load(sys.stdin):
  p=o.get('info',{}).get('props',{})
  if p.get('media.class')=='Audio/Sink': print(o['id']); break
" 2>/dev/null)
VOL=$(wpctl get-volume "$SINK" 2>/dev/null)
PCT=$(echo "$VOL" | sed 's/.* \([0-9.]*\).*/\1/' | awk '{printf "%.0f", $1*100}')
MUTED=$(echo "$VOL" | grep -ci muted)
NICK=$(pw-dump 2>/dev/null | python3 -c "
import sys,json
for o in json.load(sys.stdin):
  p=o.get('info',{}).get('props',{})
  if p.get('media.class')=='Audio/Sink' and o['id']==$SINK:
    print(p.get('node.nick',p.get('node.description','?'))); break
" 2>/dev/null)
[ "$MUTED" = "1" ] && echo " $NICK" || echo " $NICK ${PCT}%"
