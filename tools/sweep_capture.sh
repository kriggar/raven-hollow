#!/bin/bash
# PRIME MANDATE sweep: full-coverage wide screenshots of every live map.
cd "c:/Users/vstef/Desktop/rpg/medieval_rpg"
G="C:/Users/vstef/tools/godot/Godot_v4.6.3-stable_win64_console.exe"
O="c:/Users/vstef/Desktop/rpg/medieval_rpg/_screens/sweep"
mkdir -p "$O"
shoot() { # zone w h
  local z=$1 w=$2 h=$3
  mkdir -p "$O/$z"
  local m=650 stepx=1900 stepy=1050
  local y=$m r=0
  while [ $y -le $((h - m)) ]; do
    local x=$m c=0
    while [ $x -le $((w - m)) ]; do
      local f="$O/$z/r${r}c${c}.png"
      [ -f "$f" ] || RH_CLASS=warrior RH_MAP=$z RH_ZOOM=0.55 RH_NOHUD=1 RH_FOCUS="$x,$y" RH_SHOT="$f" timeout 150 "$G" res://scenes/main.tscn >/dev/null 2>&1
      x=$((x + stepx)); c=$((c + 1))
    done
    y=$((y + stepy)); r=$((r + 1))
  done
  echo "SWEEP_DONE $z $(ls "$O/$z" | wc -l) shots"
}
shoot iron_vein 6656 4608
shoot vetka 5632 4096
shoot copper_wells 6144 4608
shoot stonepath 6656 5120
shoot grey_marches 7168 5120
shoot western_lowlands 7680 5120
shoot famine_fields 7168 5120
shoot riverfork 6656 5120
shoot angel_wings 10240 8192
shoot town 2240 1600
shoot wilderness 2240 1760
echo "SWEEP_ALL_DONE"
# Batch C additions (invoked with ZONESET=north)
if [ "$ZONESET" = "north" ]; then :; fi
