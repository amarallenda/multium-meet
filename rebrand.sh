#!/usr/bin/env bash
# Rebrand Meetily -> Multium Meet (escopo restrito, seguro)
# Uso: bash rebrand.sh /caminho/logo-multium.png
set -e

LOGO="${1:-}"
if [ -z "$LOGO" ] || [ ! -f "$LOGO" ]; then
  echo "Uso: bash rebrand.sh /caminho/para/logo-multium.png"
  echo "Logo tem que ser PNG quadrado, min 1024x1024, fundo transparente."
  exit 1
fi

# Caminho absoluto do ImageMagick (ajusta se a versão instalada for diferente)
IM="/c/Program Files/ImageMagick-7.1.2-Q16-HDRI/magick.exe"
if [ ! -f "$IM" ]; then
  echo "!! ImageMagick nao encontrado em: $IM"
  echo "   Confere o caminho real e ajusta a variavel IM no topo do script."
  exit 1
fi

# ==========================================================
# ESCOPO RESTRITO: só arquivos de UI/branding, NUNCA:
# - Cargo.lock, Cargo.toml, código .rs (lógica interna)
# - .github/workflows (CI/CD)
# - docs/, README, CONTRIBUTING, LICENSE
# - backend/ (Python, scripts de build/docker)
# ==========================================================
TARGETS=(
  "frontend/src"
  "frontend/package.json"
  "frontend/src-tauri/tauri.conf.json"
)

echo "==> Trocando strings Meetily -> Multium Meet (apenas nos alvos listados)"
for target in "${TARGETS[@]}"; do
  if [ ! -e "$target" ]; then
    echo "   (aviso: $target nao existe, pulando)"
    continue
  fi
  if [ -d "$target" ]; then
    grep -rl --exclude-dir=node_modules -e "Meetily" -e "meetily" "$target" 2>/dev/null | while read -r f; do
      sed -i.bak -e 's/Meetily/Multium Meet/g' -e 's/meetily/multium-meet/g' "$f" && rm "$f.bak"
      echo "   editado: $f"
    done
  else
    if grep -q -e "Meetily" -e "meetily" "$target" 2>/dev/null; then
      sed -i.bak -e 's/Meetily/Multium Meet/g' -e 's/meetily/multium-meet/g' "$target" && rm "$target.bak"
      echo "   editado: $target"
    fi
  fi
done

echo "==> Cores da marca (azul-escuro Multium)"
if [ -f frontend/tailwind.config.ts ]; then
  sed -i.bak "s/#[0-9a-fA-F]\{6\}/#0F172A/1" frontend/tailwind.config.ts && rm frontend/tailwind.config.ts.bak
  echo "   editado: frontend/tailwind.config.ts"
fi

echo "==> Gerando icones a partir de $LOGO"
cd frontend/src-tauri/icons
for size in 32 128 256 512 1024; do
  "$IM" "$LOGO" -resize ${size}x${size} "${size}x${size}.png"
done
cp 512x512.png icon.png
cp 256x256.png 128x128@2x.png
"$IM" "$LOGO" -define icon:auto-resize=256,128,64,48,32,16 icon.ico
if command -v png2icns >/dev/null 2>&1; then
  png2icns icon.icns 16x16.png 32x32.png 128x128.png 256x256.png 512x512.png 1024x1024.png 2>/dev/null || \
    png2icns icon.icns 32x32.png 128x128.png 256x256.png 512x512.png
else
  echo "   (dica: instala 'libicns' pra gerar .icns fora do mac)"
fi
cd -

echo "==> Ajustando tauri.conf.json (productName/identifier)"
CONF=frontend/src-tauri/tauri.conf.json
if [ -f "$CONF" ]; then
  sed -i.bak \
    -e 's/"productName": *"[^"]*"/"productName": "Multium Meet"/' \
    -e 's/"identifier": *"[^"]*"/"identifier": "com.multium.meet"/' \
    "$CONF" && rm "$CONF.bak"
fi

echo "==> package.json"
if [ -f frontend/package.json ]; then
  sed -i.bak 's/"name": *"meetily[^"]*"/"name": "multium-meet"/' frontend/package.json && rm frontend/package.json.bak
fi

echo ""
echo "OK. Revisa os diffs com: git diff --stat"
echo "Esperado: SOMENTE arquivos dentro de frontend/src, frontend/package.json,"
echo "frontend/src-tauri/tauri.conf.json, frontend/src-tauri/icons/*, frontend/tailwind.config.ts"
echo "Se aparecer QUALQUER coisa fora disso (Cargo.lock, .github/, backend/, docs/), NAO COMMITA."