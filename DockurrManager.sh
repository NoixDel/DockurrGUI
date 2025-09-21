#!/bin/bash
PORT=8080
WWW_DIR=$(pwd)/www
CGI_DIR=$WWW_DIR/cgi-bin

mkdir -p $CGI_DIR

# Processus du serveur
SERVER_PID=""

# Fonction d’arrêt propre
cleanup() {
  echo "🛑 Arrêt du Dockurr Manager..."
  
  # Stop du serveur HTTP
  if [ -n "$SERVER_PID" ]; then
    kill $SERVER_PID 2>/dev/null
  fi
  pkill -f "busybox httpd" 2>/dev/null

  # Arrêt des VMs Dockurr sans persistance
  IDS=$(docker ps -q --filter "ancestor=dockurr/windows" --filter "ancestor=dockurr/macos")
  for id in $IDS; do
    NAME=$(docker inspect --format '{{.Name}}' $id | sed 's/^\/\(.*\)/\1/')
    VOLUMES=$(docker inspect --format '{{range .Mounts}}{{.Source}} {{end}}' $id)

    if [[ "$VOLUMES" == *"vmdata-"* ]]; then
      echo "💾 VM persistante conservée : $NAME"
    else
      echo "🗑️  Suppression VM temporaire : $NAME"
      docker stop "$NAME" >/dev/null 2>&1
    fi
  done

  # Suppression du dossier www
  echo "🧹 Nettoyage du dossier $WWW_DIR"
  rm -rf "$WWW_DIR"

  exit 0
}

# Capture Ctrl+C et kill
trap cleanup INT TERM

# === Script CGI principal ===
cat > $CGI_DIR/dockurr.cgi <<'EOF'
#!/bin/bash
echo "Content-type: text/html; charset=UTF-8"
echo ""

echo "<!DOCTYPE html><html lang='fr'><head><meta charset='UTF-8'>"
echo "<title>Dockurr Manager</title>"
echo "<style>
body { font-family: Arial, sans-serif; margin: 20px; background:#f4f4f9; }
h1 { color:#333; }
table { border-collapse: collapse; width: 100%; background: white; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: center; }
th { background-color: #444; color: white; }
tr:nth-child(even){background-color:#f2f2f2;}
button { padding: 6px 12px; border: none; border-radius: 5px; cursor: pointer; }
.open { background:#28a745; color:white; }
.stop { background:#dc3545; color:white; }
.log { background:#007bff; color:white; }
.restart { background:#ffc107; color:black; }
.inspect { background:#6c757d; color:white; }
</style>"
echo "</head><body>"
echo "<h1>🚀 Dockurr Manager</h1>"

# Parse QUERY_STRING
params=$(echo "$QUERY_STRING" | tr '&' '\n')
get_param() { echo "$params" | grep "^$1=" | cut -d= -f2; }
ACTION=$(get_param "action")

# === STOP ===
if [[ "$ACTION" == "stop" ]]; then
  VM_NAME=$(get_param "name")
  docker stop "$VM_NAME" >/dev/null 2>&1
  echo "<p>🛑 VM <b>$VM_NAME</b> arrêtée.</p>"
fi

# === RESTART ===
if [[ "$ACTION" == "restart" ]]; then
  VM_NAME=$(get_param "name")
  docker restart "$VM_NAME" >/dev/null 2>&1
  echo "<p>🔄 VM <b>$VM_NAME</b> redémarrée.</p>"
fi

# === LOGS ===
if [[ "$ACTION" == "logs" ]]; then
  VM_NAME=$(get_param "name")
  echo "<h2>📜 Logs de $VM_NAME</h2><pre>"
  docker logs --tail 50 "$VM_NAME" 2>&1
  echo "</pre><a href='/cgi-bin/dockurr.cgi'>⬅ Retour</a>"
  echo "</body></html>"
  exit 0
fi

# === INSPECT ===
if [[ "$ACTION" == "inspect" ]]; then
  VM_NAME=$(get_param "name")
  echo "<h2>🔍 Infos de $VM_NAME</h2><pre>"
  docker inspect "$VM_NAME"
  echo "</pre><a href='/cgi-bin/dockurr.cgi'>⬅ Retour</a>"
  echo "</body></html>"
  exit 0
fi

# === CREATE ===
if [[ "$ACTION" == "create" ]]; then
  OS=$(get_param "os")
  VERSION=$(get_param "version")
  RAM=$(get_param "ram")
  NAME=$(get_param "name")
  PERSIST=$(get_param "persist")

  if [[ -z "$NAME" ]]; then
    rand=$((RANDOM % 900 + 100))
    NAME="dockurr-${OS}${VERSION}-${rand}"
  fi

  if [[ "$OS" == "windows" ]]; then
    IMAGE="dockurr/windows"
    PORTS="-p 0:8006 -p 0:3389"
  else
    IMAGE="dockurr/macos"
    PORTS="-p 0:8006 -p 0:5900"
  fi

  if [[ "$PERSIST" == "on" ]]; then
    VOLUME="-v $(pwd)/vmdata-$NAME:/storage"
  else
    VOLUME=""
  fi

  docker run -d --name "$NAME" --rm --device /dev/kvm --device /dev/net/tun \
    --cap-add NET_ADMIN $PORTS $VOLUME -e VERSION=$VERSION -e RAM_SIZE=$RAM "$IMAGE"

  echo "<p>✅ VM <b>$NAME</b> ($OS $VERSION) lancée avec $RAM.</p>"
fi

# === Liste des VMs ===
echo "<h2>💻 VMs en cours</h2>"
echo "<table><tr><th>Nom</th><th>Image</th><th>Ports</th><th>Uptime</th><th>Persistant</th><th>Actions</th></tr>"

for c in $(docker ps -q --filter "ancestor=dockurr/windows" --filter "ancestor=dockurr/macos"); do
  NAME=$(docker inspect --format '{{.Name}}' $c | sed 's/^\/\(.*\)/\1/')
  IMAGE=$(docker inspect --format '{{.Config.Image}}' $c)
  PORTS=$(docker port $c | tr '\n' ' ')
  UPTIME=$(docker ps --filter "id=$c" --format "{{.RunningFor}}")
  NOVNC_PORT=$(docker port $c 8006/tcp | awk -F: '{print $2}')
  VOLUMES=$(docker inspect --format '{{range .Mounts}}{{.Source}} {{end}}' $c)

  if [ -n "$NOVNC_PORT" ]; then
    OPEN_BTN="<a href=\"http://localhost:$NOVNC_PORT/\" target=\"_blank\"><button class=\"open\">🌐 Ouvrir</button></a>"
  else
    OPEN_BTN="<span style='color:red;'>⚠️ Pas encore prêt</span>"
  fi

  if [[ "$VOLUMES" == *"vmdata-"* ]]; then
    PERSISTANT="✅"
  else
    PERSISTANT="❌"
  fi

  echo "<tr><td>$NAME</td><td>$IMAGE</td><td>$PORTS</td><td>$UPTIME</td><td>$PERSISTANT</td>\
<td>
$OPEN_BTN
<a href=\"/cgi-bin/dockurr.cgi?action=stop&name=$NAME\"><button class=\"stop\">🛑 Stop</button></a>
<a href=\"/cgi-bin/dockurr.cgi?action=restart&name=$NAME\"><button class=\"restart\">🔄 Restart</button></a>
<a href=\"/cgi-bin/dockurr.cgi?action=logs&name=$NAME\"><button class=\"log\">📜 Logs</button></a>
<a href=\"/cgi-bin/dockurr.cgi?action=inspect&name=$NAME\"><button class=\"inspect\">🔍 Inspect</button></a>
</td></tr>"
done
echo "</table>"

# === Formulaire création ===
echo "<h2>➕ Créer une VM</h2>"
echo '<form method="GET" action="/cgi-bin/dockurr.cgi">'
echo 'OS: <select name="os" id="osSelect" onchange="updateVersions()">'
echo '<option value="windows">Windows</option>'
echo '<option value="macos">macOS</option>'
echo '</select><br><br>'
echo 'Version: <select name="version" id="versionSelect"></select><br><br>'
echo 'RAM: <input type="text" name="ram" value="4G"><br><br>'
echo 'Nom VM (optionnel): <input type="text" name="name"><br><br>'
echo 'Persistance disque: <input type="checkbox" name="persist"><br><br>'
echo '<input type="hidden" name="action" value="create">'
echo '<input type="submit" value="Créer VM">'
echo '</form>'

# JS versions
cat <<'JAVASCRIPT'
<script>
function updateVersions() {
  var os = document.getElementById("osSelect").value;
  var versionSelect = document.getElementById("versionSelect");
  versionSelect.innerHTML = "";
  var versions = [];
  if (os === "windows") {
    versions = [
      ["11","Win 11 Pro"],["11l","Win 11 LTSC"],["11e","Win 11 Ent"],
      ["10","Win 10 Pro"],["10l","Win 10 LTSC"],["10e","Win 10 Ent"],
      ["8e","Win 8.1 Ent"],["7u","Win 7 Ult"],["vu","Vista Ult"],
      ["xp","XP Pro"],["2k","2000 Pro"],
      ["2025","Server 2025"],["2022","Server 2022"],
      ["2019","Server 2019"],["2016","Server 2016"],
      ["2012","Server 2012"],["2008","Server 2008"],["2003","Server 2003"]
    ];
  } else {
    versions = [
      ["15","macOS Sequoia"],["14","macOS Sonoma"],
      ["13","macOS Ventura"],["12","macOS Monterey"],
      ["11","macOS Big Sur"]
    ];
  }
  versions.forEach(function(v) {
    var opt = document.createElement("option");
    opt.value = v[0]; opt.text = v[1];
    versionSelect.add(opt);
  });
}
updateVersions();
</script>
JAVASCRIPT

echo "</body></html>"
EOF

chmod +x $CGI_DIR/dockurr.cgi

# === Lancer serveur + logs ===
echo "🌐 Interface disponible sur http://localhost:$PORT/cgi-bin/dockurr.cgi"
echo "📜 Suivi des logs Dockurr en temps réel (Ctrl+C pour quitter)"

busybox httpd -f -p $PORT -h $WWW_DIR &
SERVER_PID=$!

while true; do
  IDS=$(docker ps --filter "ancestor=dockurr/windows" --filter "ancestor=dockurr/macos" -q)
  if [ -n "$IDS" ]; then
    for id in $IDS; do
      echo "===== Logs $id ====="
      docker logs --tail 3 $id
    done
  fi
  sleep 2
done

