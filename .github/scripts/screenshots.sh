#!/usr/bin/env bash
# Abre o TexelProject de verdade numa tela virtual (Vulkan por software,
# lavapipe), importa um modelo (nó de toro gerado aqui, com UV), pinta em
# camadas com cores escolhidas na roda do editor de materiais e captura
# as telas para a página do app no Project Club.
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
click() { timeout 10 xdotool mousemove "$1" "$2" click 1; sleep 0.4; }
stroke() { # pincelada: x1 y1 x2 y2 [ondulação]
  local w=${5:-3}
  xdotool mousemove "$1" "$2" mousedown 1; for i in $(seq 1 30); do
    xdotool mousemove $(( $1 + ($3-$1)*i/30 )) $(( $2 + ($4-$2)*i/30 + (i%8)*w - 4*w )); sleep 0.025; done; xdotool mouseup 1; sleep 0.3; }
# Roda de cores do nó "Color" no editor de materiais (Tab abre/fecha).
# Medida no tema padrão: centro (962,354), raio ~45. Direita = azul,
# embaixo-direita = magenta, embaixo = vermelho, embaixo-esquerda =
# amarelo, esquerda = verde, em cima = ciano.
CX=962; CY=354
# O editor de materiais está aberto? Com ele aberto, o canto (1250,900)
# é o fundo escuro do editor; fechado, é o fundo cinza da cena 3D.
nodes_open() {
  local px; px=$(import -window root -crop 1x1+1250+900 +repage -depth 8 txt:- 2>/dev/null | grep -o '([0-9, .]*)' | head -1 | tr -d '() ')
  local r g b; IFS=, read -r r g b _ <<< "$px"; r=${r%.*}; g=${g%.*}; b=${b%.*}
  [ $(( (r + g + b) / 3 )) -lt 45 ]
}
set_nodes() { # set_nodes open|closed
  for _ in 1 2 3 4; do
    if [ "$1" = open ] && nodes_open; then return; fi
    if [ "$1" = closed ] && ! nodes_open; then return; fi
    xdotool mousemove 650 940; key Tab; sleep 1.5
  done
}
pick() { # pick dx dy [metálico 0-100] [aspereza 0-100]
  set_nodes open
  xdotool mousemove $CX $CY mousedown 1; sleep .15
  xdotool mousemove $((CX + $1 / 2)) $((CY + $2 / 2)); sleep .15
  xdotool mousemove $((CX + $1)) $((CY + $2)); sleep .2; xdotool mouseup 1; sleep .3
  if [ -n "${3:-}" ]; then
    xdotool mousemove 1170 397 mousedown 1; sleep .1; xdotool mousemove $((1170 + ${3} * 130 / 100)) 397; sleep .2; xdotool mouseup 1; sleep .2
  fi
  if [ -n "${4:-}" ]; then
    xdotool mousemove 1170 369 mousedown 1; sleep .1; xdotool mousemove $((1170 + ${4} * 130 / 100)) 369; sleep .2; xdotool mouseup 1; sleep .2
  fi
  set_nodes closed
}
radius() { # muda o tamanho do pincel: segura F e arrasta (px)
  xdotool mousemove 650 560 keydown f; sleep .2; xdotool mousemove $((650 + $1)) 560; sleep .2; xdotool keyup f; sleep .3
}
new_material() { click 1362 545; sleep 1.5; }
new_layer() { # new_layer paint|fill
  click 1350 65; sleep 1
  if [ "$1" = fill ]; then click 1405 107; else click 1405 79; fi
  sleep 2
}
wake() { click 120 900; sleep .3; } # 1º clique depois de fechar o editor de nós se perde
cover() { # cobre a área do modelo com pinceladas largas em zigue-zague
  for y in 250 330 410 490 570 650 730 810; do stroke 80 $y 1240 $((y + 20)) 2; done
}

# Modelo de exemplo: nó de toro (2,3) com coordenadas de UV.
MODEL="$(mktemp -d)/no-de-toro.obj"
python3 - "$MODEL" <<'PY'
import math, sys
P, Q, R, r, N, M = 2, 3, 1.9, 0.62, 300, 32
def curve(t):
    k = math.cos(Q * t) * 0.42 + 1.0
    return (k * math.cos(P * t) * R, k * math.sin(P * t) * R, math.sin(Q * t) * 0.8 * R)
def sub(a, b): return [a[i] - b[i] for i in range(3)]
def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def norm(a):
    l = math.sqrt(sum(x * x for x in a)) or 1
    return [x / l for x in a]
v, vt = [], []
for i in range(N + 1):
    t = 2 * math.pi * i / N
    c, c2 = curve(t), curve(t + 1e-3)
    T = norm(sub(c2, c)); B = norm(cross(T, [0, 0, 1])); Nn = cross(B, T)
    for j in range(M + 1):
        a = 2 * math.pi * j / M
        p = [c[k] + r * (math.cos(a) * Nn[k] + math.sin(a) * B[k]) for k in range(3)]
        v.append(p); vt.append((i / N * 6.0, j / M))
with open(sys.argv[1], 'w') as f:
    for p in v: f.write('v %.5f %.5f %.5f\n' % (p[0], p[2], p[1]))
    for u in vt: f.write('vt %.5f %.5f\n' % u)
    for i in range(N):
        for j in range(M):
            a = i * (M + 1) + j + 1; b = a + M + 1
            f.write('f %d/%d %d/%d %d/%d %d/%d\n' % (a, a, b, b, b + 1, b + 1, a + 1, a + 1))
PY

"$APP" "$MODEL" > "$OUT/app.log" 2>&1 &
APP_PID=$!
sleep 30
W=$(timeout 10 xdotool search --onlyvisible --name "TexelProject" | head -1)
[ -n "$W" ] && timeout 10 xdotool windowfocus "$W" windowsize "$W" 1600 1000 windowmove "$W" 0 0
sleep 2
key Escape
shot modelo-importado 4

# Camada de preenchimento: o modelo inteiro em roxo levemente brilhante
click 18 96
pick 40 22 0 45
new_layer fill
shot base-roxa 3

# Cada cor é um material próprio (assim a camada de preenchimento não muda).
# Faixas de cobre metálico e brilhante
new_material
pick -18 42 100 8
new_layer paint
wake; radius 120
for y in 300 420 540 660 780; do stroke 120 $y 1220 $((y + 60)) 8; done
key 3; sleep 1; wake; for y in 360 560 760; do stroke 140 $y 1200 $((y - 40)) 8; done; key 0; sleep 1
shot cobre-metalico 3

# Escamas verde-água
new_material
pick -30 -32 0 40
new_layer paint
wake; radius -70
for x in 180 330 480 630 780 930 1080; do stroke $x 260 $((x + 90)) 840 5; done
shot camadas 3

# Toques de rosa
new_material
pick 30 32 0 30
wake
for x in 260 560 860; do stroke $x 430 $((x + 240)) 480 3; stroke $x 640 $((x + 200)) 600 3; done
shot detalhes-rosa 3

# Editor de materiais aberto, com o modelo pintado ao lado
set_nodes open; shot editor-de-materiais 3
set_nodes closed

# Outros ângulos
key 3; shot vista-lateral 3
key 7; shot vista-de-cima 3
key 0; sleep 1

# Textura em 2D (o que foi pintado no mapa UV)
click 1430 72; sleep 1; shot textura-2d 4
click 1430 72; sleep 1; wake

# Navegador de arquivos e exportação
key grave; shot navegador-de-arquivos 3
key grave; sleep 1
key ctrl+e; shot exportar-texturas 4
key Escape; sleep 1

# Tela cheia sem painéis
key f11; shot sem-distracoes 3
key f11
kill $APP_PID 2>/dev/null; sleep 1
ls -la "$OUT"
pkill openbox 2>/dev/null; pkill -f "Xvfb :99" 2>/dev/null; true
