#!/usr/bin/env bash
# Redeploy the opencodex "clamp reasoning efforts to the installed Codex binary" fix into the
# copy the Codex Desktop app actually runs. Safe to re-run any time a Codex Desktop / opencodex
# update overwrites the patched files and the "unknown variant `max`" breakage comes back.
#
# Branch-independent: it pulls the patched files straight from the fix ref, so it works no matter
# which branch is checked out (you do NOT need to switch branches).
#
# Usage:
#   bash redeploy-local.sh            # deploy + verify, then relaunch Codex Desktop
#
# Overrides:
#   OCX_INSTALL=/path/to/@bitkyc08/opencodex   # target install path if the app moves
#   OCX_FIX_REF=fix/codex-reasoning-effort-clamp   # source git ref for the patched files
set -euo pipefail

# Repo = this script's own directory (the fork clone).
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The opencodex copy the running app uses (no global install exists; it's embedded in the app).
INSTALL="${OCX_INSTALL:-/home/bricol/codex-desktop-linux/codex-app/resources/node-runtime/lib/node_modules/@bitkyc08/opencodex}"

# Git ref holding the patched files. Falls back to the working tree if the ref is gone (e.g. after
# the upstream PR merges and you delete the branch — by then the fix ships in the package anyway).
FIX_REF="${OCX_FIX_REF:-fix/codex-reasoning-effort-clamp}"

FILES=(src/codex/catalog.ts src/server/index.ts)
MARKER="clampCatalogModelsToCodexSupport"

if [[ ! -d "$INSTALL" ]]; then
  echo "❌ Install opencodex introuvable: $INSTALL" >&2
  echo "   Donne le bon chemin: OCX_INSTALL=... bash redeploy-local.sh" >&2
  exit 1
fi

# Emit the patched content of a file: prefer the fix ref, else the working tree.
patched_source() {
  local f="$1"
  if git -C "$REPO" cat-file -e "$FIX_REF:$f" 2>/dev/null; then
    git -C "$REPO" show "$FIX_REF:$f"
  else
    cat "$REPO/$f"
  fi
}

echo "Repo source : $REPO  (ref: $FIX_REF)"
echo "Cible       : $INSTALL"
echo

for f in "${FILES[@]}"; do
  dst="$INSTALL/$f"
  content="$(patched_source "$f")"
  if ! grep -q "$MARKER" <<<"$content"; then
    echo "❌ Le correctif est absent de la source pour $f (ref '$FIX_REF' introuvable ?)." >&2
    exit 1
  fi
  # Back up the pristine original once, so the fix stays reversible.
  if [[ -f "$dst" && ! -f "$dst.orig-2.7.30" ]]; then
    cp "$dst" "$dst.orig-2.7.30"
    echo "  backup: $f.orig-2.7.30"
  fi
  printf '%s\n' "$content" > "$dst"
  if grep -q "$MARKER" "$dst"; then
    echo "  ✅ déployé + vérifié: $f"
  else
    echo "  ❌ vérification post-copie échouée: $f" >&2
    exit 1
  fi
done

echo
echo "✅ Correctif redéployé. Quitte complètement puis relance l'app Codex Desktop pour l'activer."
