#!/usr/bin/env bash
# Vérifie les disques et prévient Uptime Kuma (sonde « Disques »).
# Lancé toutes les 5 minutes par la crontab de l’utilisateur. Seuil : 90 % de remplissage.
SEUIL=90
# URL de la sonde « push » Uptime Kuma, rangée hors du dépôt (chmod 600)
. "$(dirname "$0")/disques.env"   # contient KUMA_PUSH_URL=http://127.0.0.1:3001/api/push/<jeton>
URL="$KUMA_PUSH_URL"
problemes=(); etat=()
for d in /media/freebox_1 /media/freebox_2 /; do
  nom=$([ "$d" = / ] && echo "Système" || echo "Freebox ${d##*_}")
  if [ "$d" != / ] && ! mountpoint -q "$d"; then problemes+=("$nom non monté"); continue; fi
  # timeout : si la Freebox ne répond plus, df resterait bloqué
  p=$(timeout 20 df --output=pcent "$d" 2>/dev/null | tail -1 | tr -dc 0-9)
  if [ -z "$p" ]; then problemes+=("$nom ne répond pas")
  elif [ "$p" -ge "$SEUIL" ]; then problemes+=("$nom plein à $p %")
  else etat+=("$nom $p %"); fi
done
if [ ${#problemes[@]} -eq 0 ]; then
  curl -fsS -m 10 -G "$URL" --data-urlencode "status=up" --data-urlencode "msg=$(printf "%s, " "${etat[@]}" | sed "s/, $//")" >/dev/null
else
  curl -fsS -m 10 -G "$URL" --data-urlencode "status=down" --data-urlencode "msg=$(printf "%s, " "${problemes[@]}" | sed "s/, $//")" >/dev/null
fi
