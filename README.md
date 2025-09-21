
# 🖥️ Dockurr Manager
Une petite interface **web locale** pour gérer facilement vos VMs **Dockurr** (Windows & macOS) en Docker.
Sans Apache, sans dépendances lourdes → juste **Bash + Busybox + Docker**. ⚡
---

## ✨ Fonctionnalités
- 🌐 **Interface Web locale** (via `busybox httpd`)
- 📋 **Liste des VMs en cours** avec :
- ✅ Nom
- 📦 Image
- 🔌 Ports
- ⏱️ Uptime
- 💾 Persistance disque (oui/non)
- 🎛️ Actions rapides :
- 🌐 **Ouvrir** (noVNC dans votre navigateur)
- 🛑 **Stop**
- 🔄 **Restart**
- 📜 **Logs** (50 dernières lignes)
- 🔍 **Inspect** (infos Docker)
- 🆕 **Création de VM** avec formulaire :
- 🪟 Windows ou 🍏 macOS
- 📌 Choix de la version (via liste déroulante)
- 💾 Option **Persistance disque** (conserve vos données dans `./vmdata-<nom>`)
- ⚡ RAM personnalisée (`4G` par défaut)
- 🏷️ Nom auto-généré si vide (ex: `dockurr-win11-123`)
---

## 🔧 Installation
Clonez ce repo et rendez le script exécutable :

```bash
git  clone  https://github.com/NoixDel/DockurrGUI.git
cd  dockurr-manager
chmod  +x  dockurr-manager.sh
```

⚠️ Prérequis :
- 🐳 **Docker** installé
- 👤 Votre utilisateur doit faire partie du groupe **docker** (`sudo usermod -aG docker $USER && newgrp docker`)
-  `busybox` (installable via `apt install busybox`)
---

## ▶️ Utilisation
Lancez le manager :
```bash
./dockurr-manager.sh
```

👉 Ouvrez ensuite [http://localhost:8080/cgi-bin/dockurr.cgi](http://localhost:8080/cgi-bin/dockurr.cgi) dans votre navigateur.
---

## 🛑 Arrêt
- Quittez avec `Ctrl + C` →
- 🗑️ Toutes les VMs **non persistantes** sont supprimées
- 💾 Les VMs **persistantes** sont conservées
- 🧹 Le dossier `www/` est automatiquement nettoyé
---

## 📸 Aperçu
  ![enter image description here](https://raw.githubusercontent.com/NoixDel/DockurrGUI/refs/heads/main/Screenshot%20From%202025-09-21%2022-34-18.png)
---

## 🚀 Exemple : Créer une VM Windows 11 Pro avec persistance
1. Ouvrir l’UI → section **Créer une VM**
2. Choisir :
- OS : `Windows`
- Version : `Win 11 Pro`
- RAM : `4G`
- Persistance disque : ✅ cochée
3. Cliquer **Créer VM**

👉 Une VM `dockurr-windows11-XYZ` démarre, accessible via noVNC.
---

## 📜 Notes
- Si aucun port n’apparaît dans la colonne “Ouvrir”, attendez quelques secondes → noVNC peut mettre un peu de temps à démarrer.
- Les volumes persistants sont créés automatiquement dans `./vmdata-<nom>`
---

## ❤️ Crédit
- Projet basé sur les images [**Dockurr**](https://github.com/dockur)
- Script shell écrit pour être simple, portable et sans dépendances externes.