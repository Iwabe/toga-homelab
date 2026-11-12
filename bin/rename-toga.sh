#!/usr/bin/env bash
# Renomme la machine « ancien-nom » en « toga » : nom système, /etc/hosts et Tailscale.
# L'ancien nom reste un alias dans /etc/hosts. Aucun redémarrage nécessaire.
#   sudo ~/bin/rename-toga.sh
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Lance ce script avec sudo."; exit 1; }

NEW=toga
OLD=$(hostname)
[ "$OLD" = "$NEW" ] && { echo "La machine s'appelle déjà $NEW."; exit 0; }

BAK=/root/rename-toga-backup-$(date +%F_%H%M)
mkdir -p "$BAK"
cp -a /etc/hostname /etc/hosts "$BAK/"
echo "Sauvegarde de /etc/hostname et /etc/hosts : $BAK"

hostnamectl set-hostname "$NEW"

# 127.0.1.1 pointe vers le nouveau nom, l'ancien reste en alias
if grep -qE "^127\.0\.1\.1[[:space:]]" /etc/hosts; then
  sed -i -E "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$NEW $OLD/" /etc/hosts
else
  printf '127.0.1.1\t%s %s\n' "$NEW" "$OLD" >> /etc/hosts
fi

tailscale set --hostname="$NEW"

echo "--- résultat"
echo "nom système : $(hostname)"
grep -E "^127\.0\.1\.1" /etc/hosts
tailscale status --self | head -1

cat <<EOF

Nouveau nom Tailscale : $NEW.tailnet-xxxx.ts.net
Pour tout annuler :
  sudo cp $BAK/hostname $BAK/hosts /etc/ && sudo hostnamectl set-hostname $OLD && sudo tailscale set --hostname=$OLD
EOF
