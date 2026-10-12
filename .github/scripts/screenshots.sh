#!/usr/bin/env bash
# Abre o TexelProject de verdade numa tela virtual (Vulkan por software,
# lavapipe) e captura telas reais para a página do app no Project Club.
set -u
APP="$(readlink -f "$1")"
OUT="$(mkdir -p "$2" && readlink -f "$2")"
chmod +x "$APP" 2>/dev/null  # o artefato do Actions perde o bit de execução
export DISPLAY=:99 APPIMAGE_EXTRACT_AND_RUN=1
Xvfb :99 -screen 0 1600x1000x24 -nolisten tcp >/dev/null 2>&1 &
sleep 2
(command -v openbox >/dev/null && DISPLAY=:99 openbox >/dev/null 2>&1 &)
sleep 2
n=0
shot() { n=$((n+1)); sleep "${2:-2}"; import -window root "$(printf '%s/%02d-%s.png' "$OUT" "$n" "$1")"; echo "captura $n: $1"; }
key() { timeout 10 xdotool key --clearmodifiers "$@"; }
stroke() { # pincelada: x1 y1 x2 y2
  xdotool mousemove "$1" "$2" mousedown 1; for i in $(seq 1 24); do
    xdotool mousemove $(( $1 + ($3-$1)*i/24 )) $(( $2 + ($4-$2)*i/24 + (i%6)*3 )); sleep 0.03; done; xdotool mouseup 1; }
"$APP" > "$OUT/app.log" 2>&1 &
APP_PID=$!
sleep 30
W=$(timeout 10 xdotool search --onlyvisible --name "TexelProject" | head -1)
[ -n "$W" ] && timeout 10 xdotool windowfocus "$W" windowsize "$W" 1600 1000 windowmove "$W" 0 0
shot inicio-projetos 4
key Escape; shot area-de-trabalho 3
stroke 650 420 900 470; stroke 640 520 920 540; stroke 700 360 760 640
shot pincel 3
key g; xdotool mousemove 800 560 click 1; shot preenchimento 3
key b; key 3; shot vista-lateral 3
key 7; shot vista-de-cima 3
key 0; key ctrl+m; shot modo-de-visualizacao 3
key ctrl+m; shot modo-de-visualizacao-2 3
key 0
key Tab; shot editor-de-nos 4
key Tab; sleep 1
key shift+Tab; shot vista-2d 4
key shift+Tab; sleep 1
key grave; shot navegador-de-arquivos 3
key grave; sleep 1
key ctrl+k; shot preferencias 4
key Escape; sleep 1
key ctrl+e; shot exportar-texturas 4
key Escape; sleep 1
key f11; shot sem-distracoes 3
key f11
kill $APP_PID 2>/dev/null; sleep 1
ls -la "$OUT"
# encerra a tela virtual e o gerenciador de janelas
pkill openbox 2>/dev/null; pkill -f "Xvfb :99" 2>/dev/null; true
