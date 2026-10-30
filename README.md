# seanime-docker

Imagen propia de [Seanime](https://github.com/5rahim/seanime) con configuración por defecto incluida: extensiones instaladas, player web y actualizaciones automáticas deshabilitadas.

Alpine 3.24 · multi-stage · binario estático · rootless · ~323 MB.

## Qué incluye

| | |
|---|---|
| **Seed** | `seed/` se copia a `/data` la primera vez y nunca más |
| **Extensiones** | 8 plugins preinstalados (AniList, torrent providers, etc.) |
| **Player** | `web` — reproduce en el navegador, sin binarios externos |
| **Updates** | `disable_update_check = 1` forzado en cada arranque |
| **Rootless** | `USER 1000` |

El seed está saneado: sin cuentas, sin credenciales de debrid, sin biblioteca.

## Requisitos

- Docker 23+ con `buildx` (en Arch/CachyOS: `pacman -S docker-buildx`)
- El source de Seanime clonado localmente
- ~4 GB libres para el build cache (primera vez)

## Preparar el source

```bash
git clone --depth 1 --branch v3.10.4 \
  https://github.com/5rahim/seanime.git \
  ~/Documents/Github/Forks/seanime-src
```

## Build

El compose espera el source en `../../Github/Forks/seanime-src` relativo al proyecto. Si lo tenés en otro lado:

```bash
export SEANIME_SRC=~/ruta/a/seanime-src
export SEANIME_DOCKERFILE=$PWD/Dockerfile
```

Y después:

```bash
docker compose build
```

O directamente con buildx:

```bash
docker buildx build \
  --build-context seed=./seed \
  -f Dockerfile \
  -t seanime:3.10.4 \
  ~/Documents/Github/Forks/seanime-src
```

## Levantar

```bash
mkdir -p data anime downloads
docker compose up -d
docker compose ps
```

Primera ejecución: el entrypoint copia `seed/` a `data/` y crea `data/.seeded`.

```
http://localhost:43211
```

## Volúmenes

| Host | Container | Contenido |
|---|---|---|
| `./data` | `/data` | DB, config, extensiones, cache |
| `./anime` | `/anime` | Biblioteca |
| `./downloads` | `/downloads` | Descargas en curso |

Los tres son bind mounts: `docker compose down` no borra nada.

## Configuración por defecto

El seed trae:

```sql
library_path         = '/anime'
default_player       = 'web'
disable_update_check = 1
download_dir         = '/downloads'
```

Para cambiarlos antes de la primera ejecución, editá `seed/seanime.db`:

```bash
sqlite3 seed/seanime.db "UPDATE settings SET default_player = 'native';"
```

## Actualizar

```bash
export SEANIME_VERSION=3.11.0
docker compose build
docker compose up -d
```

Las actualizaciones **no** se hacen desde la UI: `disable_update_check` está forzado en el entrypoint para evitar que el self-updater escriba en la capa efímera (y la actualización se pierda al recrear el container).

## Backup

```bash
docker run --rm --user "$(id -u):$(id -g)" \
  -v ./data:/data:ro \
  -v .:/backup \
  alpine tar czf /backup/seanime-data-$(date +%F).tar.gz -C /data .
```

## Estructura

```
seanime-docker/
├── Dockerfile            3 etapas: node → go → alpine
├── docker-compose.yml
├── seed/
│   ├── seanime.db        settings saneadas
│   ├── config.toml
│   ├── entrypoint.sh     siembra + bloqueo de updates
│   └── extensions/       8 plugins JSON
├── data/                 (gitignored)
├── anime/                (gitignored)
└── downloads/            (gitignored)
```

## Pitfalls conocidos

| Problema | Causa | Solución |
|---|---|---|
| `the --mount option requires BuildKit` | `docker build` cayó al builder legacy | Usar `docker buildx build` o `docker compose build` |
| El seed no copia nada | `cp -rn` de BusyBox devuelve 0 pero no copia | El entrypoint itera con `[ ! -e "$dest" ]` |
| `dockerfile` toma el equivocado | Es relativo al **contexto**, no al compose | Usar path explícito en `dockerfile:` |
| Descargas desaparecen | `download_dir` vacío → `/tmp` | El seed ya lo fija en `/downloads` |

## Licencia

El Dockerfile, el compose y el entrypoint de este repo son MIT.

Seanime es **GPL-3.0** — el binario compilado y el source derivan de [5rahim/seanime](https://github.com/5rahim/seanime).
