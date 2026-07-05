#!/bin/bash
cd "c:/Users/vstef/Desktop/rpg/medieval_rpg"
G="C:/Users/vstef/tools/godot/Godot_v4.6.3-stable_win64_console.exe"
O="c:/Users/vstef/Desktop/rpg/medieval_rpg/_screens/sweep"
shoot() {
  local z=$1 w=$2 h=$3; mkdir -p "$O/$z"; rm -f "$O/$z"/*.png
  local m=650 sx=1900 sy=1050 r=0
  local y=$m
  while [ $y -le $((h - m)) ]; do
    local x=$m c=0
    while [ $x -le $((w - m)) ]; do
      RH_CLASS=warrior RH_MAP=$z RH_TIME=12 RH_ZOOM=0.55 RH_NOHUD=1 RH_FOCUS="$x,$y" RH_SHOT="$O/$z/r${r}c${c}.png" timeout 200 "$G" res://scenes/main.tscn >/dev/null 2>&1
      x=$((x + sx)); c=$((c + 1))
    done
    y=$((y + sy)); r=$((r + 1))
  done
  echo "SWEEP_DONE $z $(ls "$O/$z" | wc -l)"
}
shoot listening_steppe 7680 5632
shoot threadlands 7680 5632
shoot black_night 10240 8192
shoot gravemark_tundra 7168 5120
shoot town 2240 1600
shoot whisper_passes 7168 5120
shoot eastern_ridges 7680 5632
shoot blestem 10240 8192
shoot lichenreach 4096 4096
shoot transcub_vale 7168 5120
shoot bloodroad 7168 5120
shoot basaltfang 7680 5632
shoot sangeroasa 10240 8192
shoot the_gift 7168 5120
shoot ashvents 7168 5120
shoot angel_wings 10240 8192
echo "FULL_SWEEP_ALL_DONE"
