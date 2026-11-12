#!/usr/bin/env bash
# Reconstruit le thème Atelier Deus de Seerr (police + logo intégrés) et le copie dans Nginx Proxy Manager.
set -euo pipefail
H=~/homepage/atelier-font
python3 - > "$H/seerr-built.css" <<'PY'
import base64, os
h = os.path.expanduser("~/homepage/atelier-font/")
b64 = lambda p: base64.b64encode(open(p, "rb").read()).decode()
css = open(h + "seerr-atelier.css").read()
css = css.replace("__FONT_DATA__", "data:font/woff2;base64," + b64(h + "jellyfin/atelier-deus.woff2"))
css = css.replace("__LOGO_DATA__", "data:image/png;base64," + b64(h + "jellyfin/toga-small.png"))
print(css)
PY
docker exec -i nginx-proxy-manager sh -c "mkdir -p /data/atelier && cat > /data/atelier/seerr.css && chmod 644 /data/atelier/seerr.css" < "$H/seerr-built.css"
echo "thème Seerr mis à jour ($(wc -c < "$H/seerr-built.css") octets)"
