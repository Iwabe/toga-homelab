#!/usr/bin/env bash
# Sauvegarde nocturne des configs du serveur vers la Freebox.
# Garde les 7 dernières archives. Lancé par cron (crontab -l).
set -euo pipefail

DEST_MOUNT=/media/freebox_1
DEST="$DEST_MOUNT/Backups/homeserver"
KEEP=7
STAMP=$(date +%F_%H%M)
STAGE=$(mktemp -d)
LOG="$HOME/.local/state/homeserver-backup.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
trap 'rm -rf "$STAGE"' EXIT
echo "=== $(date '+%F %T') début"

# Ne jamais écrire sur le disque local si le NAS n'est pas monté
if ! mountpoint -q "$DEST_MOUNT"; then
  echo "ERREUR: $DEST_MOUNT non monté, sauvegarde annulée"; exit 1
fi
mkdir -p "$DEST"

# Copies cohérentes des bases SQLite (les apps tournent pendant la sauvegarde)
while IFS= read -r -d '' db; do
  # suffixe .bak : sinon l'exclusion *.db du tar écarterait aussi ces copies
  out="$STAGE/sqlite${db}.bak"
  mkdir -p "$(dirname "$out")"
  python3 - "$db" "$out" <<'PY' || echo "WARN: copie SQLite échouée pour $db"
import shutil, sqlite3, sys
# Certains .db ne sont pas du SQLite (ex. filebrowser = BoltDB) : copie brute
with open(sys.argv[1], "rb") as f:
    if f.read(16) != b"SQLite format 3\x00":
        shutil.copy2(sys.argv[1], sys.argv[2]); sys.exit(0)
src = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True, timeout=30)
dst = sqlite3.connect(sys.argv[2])
src.backup(dst)
dst.close(); src.close()
PY
done < <(find "$HOME/jellyfin/config" "$HOME/npm/data" -maxdepth 4 \
           \( -name '*.db' -o -name '*.sqlite' \) -size +0 -readable -print0)

cp -a /etc/fstab "$STAGE/fstab"
crontab -l > "$STAGE/crontab.txt" 2>/dev/null || true

ARCHIVE="$DEST/homeserver-$STAMP.tar.gz"
tar --create --gzip --file "$ARCHIVE" --ignore-failed-read --warning=no-file-changed \
    --exclude='*.db' --exclude='*.db-wal' --exclude='*.db-shm' --exclude='*.sqlite' \
    --exclude='*/MediaCover' --exclude='*/logs' --exclude='*/log' \
    --exclude='jellyfin/config/metadata' --exclude='jellyfin/config/data/metadata' \
    --exclude='jellyfin/config/data/transcodes' --exclude='jellyfin/config/cache' \
    --exclude='homepage/config/logs' \
    -C "$HOME" jellyfin/docker-compose.yml jellyfin/config homepage npm bin \
    -C "$STAGE" . || [ $? -eq 1 ]

echo "archive: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# Rotation : ne garder que les $KEEP plus récentes
ls -1t "$DEST"/homeserver-*.tar.gz | tail -n +$((KEEP + 1)) | xargs -r rm -f --
echo "=== $(date '+%F %T') fin, $(ls -1 "$DEST"/homeserver-*.tar.gz | wc -l) archive(s) conservée(s)"
