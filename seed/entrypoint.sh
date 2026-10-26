#!/bin/sh
set -e

# Seed inicial: solo la primera vez, nunca sobreescribe datos del usuario.
# (BusyBox cp -n no copia nada con -r: se itera y se chequea con -e.)
if [ ! -f /data/.seeded ]; then
  echo "[entrypoint] Primera ejecución: copiando configuración por defecto..."
  for src in /opt/seed/*; do
    [ -e "$src" ] || continue
    dest="/data/$(basename "$src")"
    if [ ! -e "$dest" ]; then
      cp -r "$src" "$dest"
    fi
  done
  touch /data/.seeded
fi

# Actualizaciones bloqueadas: solo se actualiza reemplazando la imagen (CLI).
if [ -f /data/seanime.db ]; then
  sqlite3 /data/seanime.db \
    "UPDATE settings SET disable_update_check = 1;" 2>/dev/null || true
fi

exec "$@"
