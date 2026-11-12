#!/usr/bin/env bash
# Range le jeton du bot Telegram dans ~/monitoring/telegram.env (lisible par l’utilisateur seul), sans l'afficher.
read -rsp "Colle le jeton du bot (il ne s'affiche pas), puis Entrée : " T; echo
[ -z "$T" ] && { echo "Rien de collé, on arrête."; exit 1; }
nom=$(curl -s -m 10 "https://api.telegram.org/bot$T/getMe" | jq -r '.result.username // empty')
[ -z "$nom" ] && { echo "Telegram ne reconnaît pas ce jeton : vérifie le copier-coller."; exit 1; }
umask 077; printf 'TELEGRAM_TOKEN=%s\n' "$T" > ~/monitoring/telegram.env; unset T
echo "Rangé. Bot reconnu : @$nom"
echo "Dernière étape : dans Telegram, ouvre @$nom et appuie sur Démarrer."
