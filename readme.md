# 📦 Rsync Manager (Enterprise CLI Sync Tool)

Rsync Manager adalah tool CLI berbasis Bash untuk mengelola sinkronisasi folder menggunakan `rsync` dengan konsep **1 source = 1 destination**, mendukung mode sinkronisasi multi arah serta logging dan konfigurasi sederhana berbasis file.

---

# 🚀 Fitur

- ✔ 1 Source → 1 Destination mapping
- ✔ Support local & SSH remote sync
- ✔ Mode:
  - oneway (source → destination)
  - twoway (bidirectional sync)
  - mirror (source dominant)
- ✔ Config manager (add / delete / list)
- ✔ Logging otomatis
- ✔ CLI interaktif
- ✔ Ringan (Bash + rsync)

---

# ⚙️ Requirement

```bash
sudo apt update
sudo apt install rsync
````

Untuk SSH sync:

```bash
sudo apt install openssh-client
```

---

# 📥 Instalasi

```bash
git clone https://github.com/username/rsync-manager.git
cd rsync-manager
```

---

# 🔐 Wajib Jalankan Ini

```bash
chmod +x rsync-manager.sh
```

---

# ▶️ Menjalankan

```bash
./rsync-manager.sh
```

---

# 📁 Struktur

```text
rsync-manager/
├── rsync-manager.sh
├── rsync_manager.conf
└── rsync_manager.log
```

---

# ⚙️ Config Format

```text
source|mode|destination
```

Contoh:

```ini
[SYNC]
/home/user/Documents|twoway|/mnt/backup/Documents
/home/user/Pictures|oneway|user@192.168.1.10:/backup/Pictures
```

---

# 🔄 Mode

## ONEWAY

```
source → destination
```

## TWOWAY

```
source ⇄ destination
```

## MIRROR

```
source = master (destination disamakan)
```

---

# 🔐 SSH Setup

```bash
ssh-keygen -t ed25519
ssh-copy-id user@ip-address
```

Test:

```bash
ssh user@ip-address
```

---

# 📊 LOG

```text
rsync_manager.log
```

Contoh:

```text
[2026-06-21 14:10:00] ONEWAY /home/user/Documents -> /backup/Documents
[2026-06-21 14:12:33] TWOWAY /home/user/Pictures <-> server:/backup/Pictures
```

---

# 🧠 Use Case

* Backup data lokal
* Sync antar laptop
* Sync ke server SSH
* Alternatif Syncthing ringan (CLI)
* Automated backup system

---

# ⚠️ WARNING

Mode `twoway` tidak memiliki conflict resolution canggih. File yang berubah di kedua sisi dapat tertimpa berdasarkan timestamp `rsync`.

---

# 📜 LICENSE

MIT License

```

--- 

Kalau mau, saya bisa upgrade lagi ke:
- :contentReference[oaicite:0]{index=0}
- :contentReference[oaicite:1]{index=1}
- atau :contentReference[oaicite:2]{index=2}
```
