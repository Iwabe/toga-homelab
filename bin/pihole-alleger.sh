#!/usr/bin/env bash
# Allège Pi-hole : 12 h de requêtes en mémoire (au lieu de 24 h) et 30 jours d'historique
# sur disque (au lieu de 91). Redémarre pihole-FTL (coupure DNS de quelques secondes).
#   sudo ~/bin/pihole-alleger.sh
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Lance ce script avec sudo."; exit 1; }

BAK=/root/pihole-alleger-backup-$(date +%F_%H%M)
mkdir -p "$BAK"; cp -a /etc/pihole/pihole.toml "$BAK/"
echo "Sauvegarde de pihole.toml : $BAK"

avant=$(awk '/VmRSS/{print int($2/1024)}' /proc/$(pgrep -x pihole-FTL)/status)

pihole-FTL --config webserver.api.maxHistory 43200 >/dev/null
pihole-FTL --config database.maxDBdays 30 >/dev/null
echo "maxHistory = $(pihole-FTL --config webserver.api.maxHistory) s, maxDBdays = $(pihole-FTL --config database.maxDBdays) j"

systemctl restart pihole-FTL
for i in $(seq 1 30); do dig +short +time=1 +tries=1 pihole.home @127.0.0.1 >/dev/null 2>&1 && break; sleep 1; done
echo "DNS de nouveau en service : $(dig +short pihole.home @127.0.0.1)"
sleep 20
apres=$(awk '/VmRSS/{print int($2/1024)}' /proc/$(pgrep -x pihole-FTL)/status)
echo "Mémoire pihole-FTL : $avant Mo avant, $apres Mo juste après redémarrage (remonte un peu en se remplissant sur 12 h)"

cat <<EOF

Pour tout annuler :
  sudo cp $BAK/pihole.toml /etc/pihole/ && sudo systemctl restart pihole-FTL
EOF
