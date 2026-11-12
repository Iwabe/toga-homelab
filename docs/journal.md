# Journal des interventions

Chaque entrée : le symptôme, le diagnostic, la correction et la vérification.

## Novembre 2026 — Supervision et alertes

- **Besoin :** être prévenu quand un service ou un disque tombe.
- **Mise en place :** stack `monitoring/` (Uptime Kuma + ntfy) ; 12 sondes HTTP sur
  les endpoints de santé de chaque service ; sonde « push » alimentée par
  `check-disques.sh` (cron, toutes les 5 min).
- **Problème :** les notifications push ntfy n'arrivaient pas sur iPhone, même en
  passant directement par le serveur public ntfy.sh (relais vérifié côté serveur).
- **Solution :** alertes via un bot Telegram ; ntfy conservé comme historique local.
- **Vérification :** test de bascule (seuil abaissé temporairement) → alerte reçue.

## Novembre 2026 — Mémoire saturée (4 Go)

- **Constat :** 1,7 Go disponible seulement.
- **Actions :** arrêt de FlareSolverr (plus utilisé par aucun indexeur, placé dans
  un *profile* Compose pour ne pas être relancé) ; Pi-hole allégé
  (`webserver.api.maxHistory` 12 h, `database.maxDBdays` 30).
- **Résultat :** 2,0 Go disponibles ; Pi-hole de 214 à 110 Mo.

## Novembre 2026 — Téléchargements en erreur « Bad address »

- **Symptôme :** qBittorrent en erreur `file_write error: Bad address` sur les
  fichiers écrits vers le disque réseau.
- **Diagnostic :** le mode d'E/S par défaut (fichiers mappés en mémoire, *mmap*)
  est incompatible avec les partages CIFS/SMB.
- **Correction :** `disk_io_type` passé en E/S POSIX, puis redémarrage du conteneur
  (le réglage n'est pris en compte qu'au démarrage), revérification et reprise.
- **Vérification :** téléchargement reparti, aucune erreur.

## Novembre 2026 — Film 4K qui saccade

- **Symptôme :** un film 4K (≈ 5 Mb/s) s'arrête régulièrement, lu en direct (sans transcodage).
- **Diagnostic :** mesures de latence et de débit sur chaque tronçon. Serveur → poste :
  0,3 Mo/s et 85 ms ; poste → point d'accès CPL : 11 ms. Le goulot était donc le CPL,
  branché sur une multiprise (qui filtre et atténue le signal).
- **Correction :** adaptateur CPL branché directement sur une prise murale.
- **Résultat :** 3,3 Mo/s (×10) et 14 à 25 ms, largement suffisant pour la 4K.

## Novembre 2026 — Wi-Fi et sécurité de la box

Audit par l'API de la box (application dédiée, droits accordés explicitement) :
- **Économie d'énergie Wi-Fi** désactivée : une des deux radios 5 GHz était éteinte
  alors que 8 appareils se partageaient l'autre.
- **Pare-feu IPv6 activé** : le serveur avait une IPv6 publique et 20 services
  en écoute, tous joignables depuis internet.
- **WPS désactivé** sur les 4 réseaux.
- **Bail DHCP réservé** pour l'adresse fixe du serveur (risque de conflit d'IP
  qui aurait coupé le DNS de toute la maison).
- Sauvegarde de la configuration avant chaque modification, vérifications après
  (DNS, IPv4/IPv6 sortant, Tailscale, toutes les sondes).

## Novembre 2026 — Jellyfin accessible en HTTPS depuis l'extérieur

- **Avant :** port 8096 ouvert en HTTP : identifiants et flux en clair.
- **Mise en place :** nom de domaine dynamique fourni par l'opérateur, redirection
  du port 443 vers Nginx Proxy Manager, hôte proxy dédié (WebSocket, pas de mise en
  tampon), certificat Let's Encrypt (défi HTTP-01), HTTPS forcé, HTTP/2.
- **Problème rencontré :** « connexion refusée » dans Chrome. Le domaine a aussi un
  enregistrement IPv6 (AAAA) qui pointe vers la box elle-même, et non vers le serveur ;
  Chrome, avec son DNS sécurisé, contournait Pi-hole (qui ne renvoie que l'IPv4).
- **Clôture :** port 8096 fermé une fois l'accès HTTPS validé.

## Novembre 2026 — File Browser n'affiche plus les disques

- **Symptôme :** les disques réseau n'apparaissent plus dans le gestionnaire de fichiers.
- **Diagnostic :** les disques sont bien montés sur l'hôte et dans le conteneur. La
  racine de File Browser était « . » (dossier courant) ; une mise à jour de l'image
  a changé le dossier de travail de `/srv` à `/`.
- **Correction :** `--root /srv` explicite dans la commande. Le montage d'un
  `settings.json` inexistant (Docker l'avait créé comme dossier) cassait aussi le
  *healthcheck* : montage retiré, volume anonyme recréé (`docker compose up -V`).
- **Vérification :** conteneur « healthy », les trois espaces de stockage visibles.
