#!/usr/bin/env bash
# Appel à l API Freebox avec la clé de Toga. Usage : fbx.sh GET|PUT|POST chemin [json]
B=http://mafreebox.freebox.fr/api/v16
T=$(cat ~/freebox/app_token)
CH=$(curl -s -m 10 $B/login/ | jq -r .result.challenge)
PW=$(printf "%s" "$CH" | openssl dgst -sha1 -hmac "$T" | awk "{print \$NF}")
S=$(curl -s -m 10 -H "Content-Type: application/json" -d "{\"app_id\":\"fr.toga.reglages\",\"password\":\"$PW\"}" $B/login/session/ | jq -r .result.session_token)
if [ -n "$3" ]; then curl -s -m 60 -X "$1" -H "X-Fbx-App-Auth: $S" -H "Content-Type: application/json" -d "$3" "$B$2"
else curl -s -m 60 -X "$1" -H "X-Fbx-App-Auth: $S" "$B$2"; fi
