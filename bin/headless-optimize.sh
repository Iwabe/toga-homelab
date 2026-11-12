#!/usr/bin/env bash
# Allège le serveur : sans bureau graphique, services inutiles coupés,
# swap moins agressif, journaux système et logs Docker limités.
# Rien n'est désinstallé : tout est réversible (voir la fin de ce script).
#
#   sudo ~/bin/headless-optimize.sh            # tout sauf Samba
#   sudo ~/bin/headless-optimize.sh --samba    # coupe aussi le partage Samba
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Lance ce script avec sudo."; exit 1; }

# Docker redémarre en fin de script : ne pas couper un déplacement de films
if pgrep -x rsync >/dev/null; then
  echo "Un rsync tourne encore (déplacement des films) : relance plus tard."; exit 1
fi
RK=$(grep -oP '(?<=<ApiKey>)[^<]+' /home/admin/jellyfin/config/radarr/config.xml)
if curl -s -m 10 -H "X-Api-Key: $RK" http://127.0.0.1:7878/api/v3/command \
   | jq -e '[.[] | select((.name=="BulkMoveMovie" or .name=="MoveMovie") and (.status=="started" or .status=="queued"))] | length > 0' >/dev/null; then
  echo "Radarr déplace encore des films : relance plus tard."; exit 1
fi

BAK=/root/headless-optimize-backup-$(date +%F_%H%M)
mkdir -p "$BAK"
systemctl get-default > "$BAK/default-target"
cp -a /etc/docker/daemon.json "$BAK/" 2>/dev/null || true
echo "État d'origine sauvegardé dans $BAK"

echo "--- 1. Démarrage sans bureau graphique"
systemctl set-default multi-user.target
systemctl stop lightdm || true

echo "--- 2. Services inutiles sur un serveur sans écran"
SERVICES=(bluetooth cups cups-browsed colord ModemManager touchegg kerneloops switcheroo-control)
[ "${1:-}" = "--samba" ] && SERVICES+=(smbd nmbd)
for s in "${SERVICES[@]}"; do
  if systemctl list-unit-files "$s.service" --no-legend | grep -q .; then
    systemctl is-enabled "$s" >> "$BAK/services-enabled.txt" 2>&1 || true
    systemctl disable --now "$s" 2>/dev/null && echo "  coupé : $s"
  fi
done
systemctl disable --now fwupd-refresh.timer 2>/dev/null && echo "  coupé : fwupd-refresh.timer"
printf '%s\n' "${SERVICES[@]}" fwupd-refresh.timer > "$BAK/services-coupes.txt"

echo "--- 3. Swap moins agressif"
echo 'vm.swappiness=10' > /etc/sysctl.d/90-homeserver.conf
sysctl -q --system && echo "  vm.swappiness=$(cat /proc/sys/vm/swappiness)"

echo "--- 4. Journaux système limités à 200 Mo"
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nSystemMaxUse=200M\n' > /etc/systemd/journald.conf.d/90-size.conf
systemctl restart systemd-journald
journalctl --vacuum-size=200M -q
echo "  $(journalctl --disk-usage)"

echo "--- 5. Rotation des logs Docker (10 Mo x 3 par conteneur)"
if [ -f /etc/docker/daemon.json ]; then
  jq '. + {"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' \
    /etc/docker/daemon.json > /etc/docker/daemon.json.new
else
  echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' > /etc/docker/daemon.json.new
fi
mv /etc/docker/daemon.json.new /etc/docker/daemon.json
echo "  taille des logs Docker avant : $(du -sh /var/lib/docker/containers | cut -f1)"
systemctl restart docker
# La rotation ne s'applique qu'aux conteneurs recréés
for d in /home/admin/jellyfin /home/admin/homepage /home/admin/npm; do
  sudo -u admin docker compose --project-directory "$d" up -d --force-recreate --remove-orphans 2>&1 | tail -1
done
# Jackett reste arrêté (remplacé par Prowlarr)
sudo -u admin docker stop jackett >/dev/null 2>&1 || true

echo "--- Résultat"
free -h | head -2
sudo -u admin docker ps --format '{{.Names}}\t{{.Status}}'

cat <<EOF

Pour tout annuler :
  sudo systemctl set-default $(cat "$BAK/default-target")
  sudo systemctl enable --now \$(cat $BAK/services-coupes.txt)
  sudo rm /etc/sysctl.d/90-homeserver.conf /etc/systemd/journald.conf.d/90-size.conf
  sudo cp $BAK/daemon.json /etc/docker/daemon.json   # ou le supprimer s'il n'existait pas
  sudo reboot
EOF
