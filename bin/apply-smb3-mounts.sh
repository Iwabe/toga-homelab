#!/usr/bin/env bash
# Passe les montages Freebox de SMB1 à SMB3 et fait attendre Docker le NAS au démarrage.
# À lancer avec sudo, une fois les déplacements de films terminés :
#   sudo ~/bin/apply-smb3-mounts.sh
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Lance ce script avec sudo."; exit 1; }

STACK=/home/admin/jellyfin
OPTS='_netdev,nofail,guest,vers=3.0,uid=1000,gid=1000,file_mode=0775,dir_mode=0775,x-systemd.mount-timeout=60'
BAK=/etc/fstab.bak-$(date +%F_%H%M)

if pgrep -x rsync >/dev/null; then
  echo "Un rsync tourne encore (déplacement des films) : relance plus tard."; exit 1
fi
RK=$(grep -oP '(?<=<ApiKey>)[^<]+' /home/admin/jellyfin/config/radarr/config.xml)
if curl -s -m 10 -H "X-Api-Key: $RK" http://127.0.0.1:7878/api/v3/command \
   | jq -e '[.[] | select((.name=="BulkMoveMovie" or .name=="MoveMovie") and (.status=="started" or .status=="queued"))] | length > 0' >/dev/null; then
  echo "Radarr déplace encore des films : relance plus tard."; exit 1
fi
if ! curl -s -m 10 -o /dev/null -H "X-Api-Key: $RK" http://127.0.0.1:7878/api/v3/system/status; then
  echo "Radarr ne répond pas, impossible de vérifier ses déplacements : arrêt par prudence."; exit 1
fi

cp -a /etc/fstab "$BAK"
echo "fstab sauvegardé : $BAK"
sed -i -E \
  -e "s#^(//192\.168\.1\.254/Disque\\\\0401[[:space:]]+/media/freebox_1[[:space:]]+cifs)[[:space:]]+.*#\1 $OPTS 0 0#" \
  -e "s#^(//192\.168\.1\.254/Disque\\\\0402[[:space:]]+/media/freebox_2[[:space:]]+cifs)[[:space:]]+.*#\1 $OPTS 0 0#" \
  /etc/fstab
echo "--- nouvelles lignes fstab :"; grep freebox /etc/fstab

mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/wait-nas.conf <<'EOF'
[Unit]
# Démarrer Docker après les partages Freebox, sans bloquer si le NAS est absent (nofail)
Wants=media-freebox_1.mount media-freebox_2.mount
After=media-freebox_1.mount media-freebox_2.mount remote-fs.target
EOF
systemctl daemon-reload
systemctl reset-failed mnt-freebox_disque1.mount mnt-freebox_disque2.mount 2>/dev/null || true

echo "--- arrêt de la stack média"
sudo -u admin docker compose --project-directory "$STACK" stop

remount() {
  umount /media/freebox_1 /media/freebox_2
  mount /media/freebox_1 && mount /media/freebox_2
}
if remount; then
  echo "--- montages SMB3 OK"
else
  echo "!!! échec du montage SMB3, retour à l'ancien fstab"
  cp -a "$BAK" /etc/fstab; systemctl daemon-reload
  umount /media/freebox_1 /media/freebox_2 2>/dev/null || true
  mount /media/freebox_1; mount /media/freebox_2
fi
mount | grep -E 'freebox_[12]' | sed -E 's/,(rsize|wsize|bsize|echo_interval|actimeo|closetimeo)=[0-9]+//g'

echo "--- redémarrage de la stack média"
sudo -u admin docker compose --project-directory "$STACK" start
sudo -u admin docker ps --format '{{.Names}}\t{{.Status}}'
