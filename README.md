# Menú El Bambú + Panel de administración

Sitio estático (`index.html`) que lee el menú de una API propia, y un panel (`admin.html`) para que el restaurante agregue, edite, oculte y ordene sus productos y suba fotos, sin tocar código.

```
Navegador ──HTTPS──> nginx ──> /            sitio estático (index.html, admin.html, img/)
                          ├──> /uploads/    fotos subidas desde el panel
                          └──> /api/*  ──>  API Node (127.0.0.1:3010) ──> Postgres (solo local)
```

| Carpeta / archivo | Qué es |
|---|---|
| `index.html` | Menú público. Lee `/api/menu`; si falla usa la última copia guardada en el dispositivo y, en su defecto, `menu-fallback.js` |
| `admin.html` | Panel (login por usuario y contraseña) |
| `server/` | API en Node/Express (`server.js`), hash de contraseñas (`password.js`) y `create-admin.js` |
| `db/` | `schema.sql` (tablas) y `seed.sql` (los 174 productos originales) |
| `deploy/` | `setup-server.sh` (instalación en el VPS, una vez) y `deploy.sh` (actualizaciones) |
| `menu-fallback.js` | Copia estática del menú (respaldo de emergencia, no se actualiza sola) |
| `config.js` | Opcional: `window.BAMBU_API` si el menú se sirve desde otro dominio |

## Cómo funciona
- **Categoría** = una sección del menú. Elige su pantalla (Entradas, Principales, Postres, Bebidas) y su formato: *tarjetas con foto* o *lista simple*. En Bebidas, las categorías con la misma **pestaña** se agrupan.
- **Agotado**: se ve en el menú marcado como “Agotado”. **Oculto**: desaparece del menú sin borrarse.
- Las fotos se reducen a ~1200 px (JPEG) en el navegador antes de subirse; el servidor valida que sean imágenes reales.
- Seguridad: sesión en cookie `HttpOnly + Secure + SameSite=Strict`, contraseñas con scrypt, límite de intentos de login, escritura solo con sesión y consultas SQL parametrizadas. Postgres solo escucha en `localhost`.

## Instalación en el VPS (una sola vez)
Requisitos: Ubuntu con nginx, Postgres, Node 20 y certbot; un dominio apuntando al servidor.

1. Crear el usuario `bambu` y autorizar la llave SSH de despliegue (sin privilegios de root).
2. `deploy/deploy.sh` sube el código; luego, como root en el servidor:
   `DOMAINS="menu.midominio.com" /root/setup-server.sh` (sin `DOMAINS` usa `elbamburestaurante.com`)
   (crea base y rol `bambu`/`bambu_db`, servicio `bambu-api`, sitio nginx, HTTPS, respaldos diarios y el usuario `admin` con una clave aleatoria que imprime una sola vez).
3. Entrar a `https://<dominio>/admin.html`, y cambiar la contraseña desde el propio panel.

## Actualizar
```
deploy/deploy.sh      # sube sitio + API, instala dependencias y reinicia el servicio
```
Cambiar la clave de un usuario (en el servidor, como `bambu`): `node server/create-admin.js admin <clave-nueva>`.

## Respaldos
Cada día a las 3:30 (14 días de historial) en `/var/backups/bambu`: volcado de la base y carpeta de fotos.

## Desarrollo local
Necesita un Postgres local con `db/schema.sql` y `db/seed.sql` cargados (con `psql`). Luego:
`DATABASE_URL=postgres://usuario:clave@127.0.0.1:5432/base STATIC_DIR=. COOKIE_SECURE=false npm run dev`
y abrir `http://127.0.0.1:3010`. Crear un administrador: `DATABASE_URL=... npm run create-admin -- admin`.
