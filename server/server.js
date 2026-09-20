'use strict';
// API del menú de El Bambú.
//   GET  /api/menu            público: categorías con sus productos visibles
//   POST /api/login|logout    sesión del panel (cookie httpOnly)
//   /api/admin/*              solo con sesión: CRUD de categorías y productos, fotos, orden
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');
const { Pool } = require('pg');
const { hashPassword, verifyPassword } = require('./password');
const mailer = require('./mailer');

const PORT = +process.env.PORT || 3010;
const UPLOAD_DIR = path.resolve(process.env.UPLOAD_DIR || path.join(__dirname, 'uploads'));
const PUBLIC_URL = (process.env.PUBLIC_URL || '').replace(/\/+$/, '');   // para cuando el menú se sirve desde otro dominio
const STATIC_DIR = process.env.STATIC_DIR ? path.resolve(process.env.STATIC_DIR) : null;   // solo desarrollo local
const COOKIE_SECURE = process.env.COOKIE_SECURE !== 'false';
const COOKIE = 'bambu_sid';
const SESSION_DAYS = 7;

if (!process.env.DATABASE_URL) { console.error('Falta DATABASE_URL'); process.exit(1); }
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 8 });
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const SCREENS = ['entradas', 'principales', 'postres', 'bebidas'];
const LAYOUTS = ['cards', 'list'];

class HttpError extends Error { constructor(status, message) { super(message); this.status = status; } }
const bad = msg => new HttpError(400, msg);

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 'loopback');   // nginx está en la misma máquina
app.use(express.json({ limit: '100kb' }));

app.use((req, res, next) => {
  res.set({ 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'same-origin' });
  if (req.path.startsWith('/api/')) res.set('Cache-Control', 'no-store');
  next();
});

// CSRF: la cookie es SameSite=Strict y además todo lo que escribe exige este header,
// que un sitio ajeno no puede enviar sin permiso CORS.
app.use('/api', (req, res, next) => {
  if (!['GET', 'HEAD', 'OPTIONS'].includes(req.method) && req.get('x-requested-with') !== 'bambu') {
    return next(new HttpError(403, 'Solicitud no permitida'));
  }
  next();
});

// ── sesión ───────────────────────────────────────────────────────────────────
const sha256 = s => crypto.createHash('sha256').update(s).digest('hex');
const readCookie = (req, name) => {
  const m = (req.headers.cookie || '').split(/;\s*/).find(c => c.startsWith(name + '='));
  return m ? decodeURIComponent(m.slice(name.length + 1)) : null;
};
const setSessionCookie = (res, token, maxAgeSec) =>
  res.append('Set-Cookie', `${COOKIE}=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${maxAgeSec}${COOKIE_SECURE ? '; Secure' : ''}`);

async function auth(req, res, next) {
  const token = readCookie(req, COOKIE);
  if (!token) return next(new HttpError(401, 'Inicia sesión'));
  const { rows } = await pool.query(
    `select u.id, u.username from sessions s join admin_users u on u.id = s.user_id
     where s.token_hash = $1 and s.expires_at > now()`, [sha256(token)]);
  if (!rows[0]) return next(new HttpError(401, 'Tu sesión venció. Vuelve a entrar.'));
  req.user = rows[0]; req.tokenHash = sha256(token);
  next();
}

// límite de intentos de login (memoria: un solo proceso)
const attempts = new Map();
const WINDOW_MS = 15 * 60 * 1000, MAX_ATTEMPTS = 8;
function tooMany(key) {
  const now = Date.now(), a = attempts.get(key);
  if (!a || now - a.first > WINDOW_MS) return false;
  return a.count >= MAX_ATTEMPTS;
}
function noteFailure(key) {
  const now = Date.now(), a = attempts.get(key);
  if (!a || now - a.first > WINDOW_MS) attempts.set(key, { first: now, count: 1 }); else a.count++;
}
setInterval(() => { const now = Date.now(); for (const [k, a] of attempts) if (now - a.first > WINDOW_MS) attempts.delete(k); }, 60_000).unref();

// ── validación ───────────────────────────────────────────────────────────────
const IMAGE_RE = /^(\/uploads\/[A-Za-z0-9._-]+|img\/[A-Za-z0-9._\/-]+)$/;
const isStr = (v, max, min = 0) => typeof v === 'string' && v.trim().length >= min && v.length <= max;

function parseCategory(b, partial) {
  const o = {};
  if (!partial || 'name' in b)   { if (!isStr(b.name, 80, 1)) throw bad('Escribe el nombre de la categoría (máx. 80 letras).'); o.name = b.name.trim(); }
  if (!partial || 'screen' in b) { if (!SCREENS.includes(b.screen)) throw bad('Pantalla no válida.'); o.screen = b.screen; }
  if (!partial || 'layout' in b) { if (!LAYOUTS.includes(b.layout)) throw bad('Formato no válido.'); o.layout = b.layout; }
  if ('tab' in b) {
    if (b.tab != null && !isStr(b.tab, 40)) throw bad('La pestaña es demasiado larga.');
    o.tab = b.tab && b.tab.trim() ? b.tab.trim() : null;
  }
  if ('sort' in b) { if (!Number.isInteger(b.sort)) throw bad('Orden no válido.'); o.sort = b.sort; }
  if (o.screen && o.screen !== 'bebidas') o.tab = null;
  return o;
}

function parseProduct(b, partial) {
  const o = {};
  if (!partial || 'category_id' in b) { if (!Number.isInteger(b.category_id)) throw bad('Elige una categoría.'); o.category_id = b.category_id; }
  if (!partial || 'name' in b)        { if (!isStr(b.name, 120, 1)) throw bad('Escribe el nombre del producto (máx. 120 letras).'); o.name = b.name.trim(); }
  if ('description' in b)             { if (b.description != null && !isStr(b.description, 300)) throw bad('La descripción es demasiado larga (máx. 300).'); o.description = (b.description || '').trim(); }
  if (!partial || 'price' in b)       { if (typeof b.price !== 'number' || !isFinite(b.price) || b.price < 0 || b.price > 9_999_999) throw bad('Escribe un precio válido (0 o más).'); o.price = Math.round(b.price * 100) / 100; }
  if ('image_url' in b)               { if (b.image_url != null && (typeof b.image_url !== 'string' || !IMAGE_RE.test(b.image_url) || b.image_url.includes('..'))) throw bad('Imagen no válida.'); o.image_url = b.image_url || null; }
  if ('available' in b)               { if (typeof b.available !== 'boolean') throw bad('Valor no válido.'); o.available = b.available; }
  if ('visible' in b)                 { if (typeof b.visible !== 'boolean') throw bad('Valor no válido.'); o.visible = b.visible; }
  if ('sort' in b)                    { if (!Number.isInteger(b.sort)) throw bad('Orden no válido.'); o.sort = b.sort; }
  return o;
}

// arma INSERT / UPDATE a partir de un objeto ya validado (los nombres de columna salen del validador, no del cliente)
function insertSql(table, o) {
  const keys = Object.keys(o);
  return { text: `insert into ${table} (${keys.join(', ')}) values (${keys.map((_, i) => '$' + (i + 1)).join(', ')}) returning *`, values: keys.map(k => o[k]) };
}
function updateSql(table, o, id) {
  const keys = Object.keys(o);
  if (!keys.length) throw bad('Nada que actualizar.');
  return { text: `update ${table} set ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')} where id = $${keys.length + 1} returning *`, values: [...keys.map(k => o[k]), id] };
}

// ── fotos ────────────────────────────────────────────────────────────────────
function sniffImage(buf) {
  if (buf.length > 12 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.length > 12 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (buf.length > 12 && buf.subarray(0, 4).toString() === 'RIFF' && buf.subarray(8, 12).toString() === 'WEBP') return 'webp';
  return null;
}
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 6 * 1024 * 1024, files: 1 } });

// borra un archivo subido desde el panel, solo si nadie más lo usa
async function dropUpload(url) {
  const m = /^\/uploads\/([A-Za-z0-9._-]+)$/.exec(url || '');
  if (!m) return;   // fotos del repo (img/...) no se tocan
  const file = path.join(UPLOAD_DIR, m[1]);
  if (path.dirname(file) !== UPLOAD_DIR) return;
  const { rowCount } = await pool.query('select 1 from products where image_url = $1 limit 1', [url]);
  if (rowCount) return;
  await fs.promises.unlink(file).catch(e => { if (e.code !== 'ENOENT') console.warn('No se pudo borrar', file, e.message); });
}

// ── menú ─────────────────────────────────────────────────────────────────────
async function loadMenu(includeHidden) {
  const cats = (await pool.query('select id, name, screen, tab, layout, sort from categories order by sort, id')).rows;
  const prods = (await pool.query(
    `select id, category_id, name, description, price::float8 as price, image_url, available, visible, sort
     from products ${includeHidden ? '' : 'where visible'} order by sort, created_at`)).rows;
  const by = new Map(cats.map(c => [c.id, Object.assign(c, { products: [] })]));
  for (const p of prods) {
    if (!includeHidden && PUBLIC_URL && p.image_url && p.image_url.startsWith('/uploads/')) p.image_url = PUBLIC_URL + p.image_url;
    by.get(p.category_id)?.products.push(p);
  }
  return cats;
}

app.get('/api/health', async (req, res) => { await pool.query('select 1'); res.json({ ok: true }); });

app.get('/api/menu', async (req, res) => {
  res.set({ 'Cache-Control': 'no-cache', 'Access-Control-Allow-Origin': '*' });   // solo lectura pública
  res.json({ categories: await loadMenu(false) });
});

// ── sesión: login / logout / me ──────────────────────────────────────────────
const DUMMY_HASH = 'scrypt$16384$8$1$AAAAAAAAAAAAAAAAAAAAAA==$' + Buffer.alloc(64).toString('base64');

app.post('/api/login', async (req, res) => {
  const username = String(req.body?.username || '').trim().slice(0, 100);
  const password = String(req.body?.password || '').slice(0, 200);
  const keys = ['ip:' + req.ip, 'u:' + username.toLowerCase()];
  if (keys.some(tooMany)) throw new HttpError(429, 'Demasiados intentos. Espera unos minutos e intenta de nuevo.');
  const { rows } = await pool.query('select id, username, password_hash from admin_users where lower(username) = lower($1)', [username]);
  const ok = await verifyPassword(password, rows[0]?.password_hash || DUMMY_HASH);   // mismo costo exista o no el usuario
  if (!rows[0] || !ok) { keys.forEach(noteFailure); throw new HttpError(401, 'Usuario o contraseña incorrectos.'); }
  keys.forEach(k => attempts.delete(k));
  const token = crypto.randomBytes(32).toString('base64url');
  await pool.query('insert into sessions (token_hash, user_id, expires_at) values ($1, $2, now() + $3 * interval \'1 day\')', [sha256(token), rows[0].id, SESSION_DAYS]);
  setSessionCookie(res, token, SESSION_DAYS * 86400);
  res.json({ user: { username: rows[0].username } });
});

app.post('/api/logout', async (req, res) => {
  const token = readCookie(req, COOKIE);
  if (token) await pool.query('delete from sessions where token_hash = $1', [sha256(token)]);
  setSessionCookie(res, '', 0);
  res.json({ ok: true });
});

app.get('/api/me', auth, (req, res) => res.json({ user: { username: req.user.username } }));

// ── recuperar contraseña ─────────────────────────────────────────────────────
// Nunca se envía la contraseña: se envía un enlace de un solo uso que vale 30 minutos.
const RESET_MINUTES = 30;
const resetAsks = new Map();   // límite de solicitudes (memoria: un solo proceso)
function limited(key, max, windowMs = 3600_000) {
  const now = Date.now(), a = resetAsks.get(key);
  if (!a || now - a.first > windowMs) { resetAsks.set(key, { first: now, count: 1 }); return false; }
  return ++a.count > max;
}
setInterval(() => { const now = Date.now(); for (const [k, a] of resetAsks) if (now - a.first > 3600_000) resetAsks.delete(k); }, 60_000).unref();

async function sendReset(email) {
  const { rows } = await pool.query('select id, username from admin_users where lower(username) = $1', [email]);
  if (!rows[0]) return;   // sin cuenta: no se envía nada (y quien pidió no lo sabe)
  const token = crypto.randomBytes(32).toString('base64url');
  await pool.query('delete from password_resets where user_id = $1 or expires_at < now()', [rows[0].id]);
  await pool.query(`insert into password_resets (token_hash, user_id, expires_at) values ($1, $2, now() + $3 * interval '1 minute')`,
    [sha256(token), rows[0].id, RESET_MINUTES]);
  const link = `${mailer.siteUrl()}/admin.html#reset=${token}`;
  await mailer.sendMail({
    to: rows[0].username,
    subject: 'Crea una contraseña nueva · Panel El Bambú',
    text: `Recibimos una solicitud para cambiar la contraseña del panel de El Bambú.\n\n` +
          `Abre este enlace para crear una contraseña nueva (vale ${RESET_MINUTES} minutos y solo se puede usar una vez):\n${link}\n\n` +
          `Si no fuiste tú, ignora este correo: tu contraseña actual sigue igual.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#1e3d1a">` +
          `<h2 style="margin:0 0 12px">Panel El Bambú</h2>` +
          `<p>Recibimos una solicitud para cambiar la contraseña del panel.</p>` +
          `<p><a href="${link}" style="display:inline-block;background:#3a6b35;color:#fff;text-decoration:none;padding:12px 22px;border-radius:30px;font-weight:bold">Crear contraseña nueva</a></p>` +
          `<p style="font-size:13px;color:#555">El enlace vale ${RESET_MINUTES} minutos y solo se puede usar una vez.<br>Si no fuiste tú, ignora este correo: tu contraseña actual sigue igual.</p></div>`,
  });
}

app.post('/api/forgot', async (req, res) => {
  if (!mailer.isConfigured()) throw new HttpError(503, 'El envío de correos todavía no está configurado en el servidor.');
  const email = String(req.body?.email || '').trim().toLowerCase().slice(0, 200);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw bad('Escribe tu correo.');
  if (limited('ip:' + req.ip, 10) || limited('e:' + email, 3)) throw new HttpError(429, 'Demasiadas solicitudes. Intenta de nuevo en una hora.');
  res.json({ ok: true });   // misma respuesta exista o no la cuenta: no se puede usar para averiguar correos
  try { await sendReset(email); } catch (e) { console.error('[forgot] no se pudo enviar:', e.message); }
});

app.post('/api/reset', async (req, res) => {
  const token = String(req.body?.token || '');
  const password = req.body?.password;
  if (!/^[A-Za-z0-9_-]{20,100}$/.test(token)) throw bad('El enlace no es válido.');
  if (typeof password !== 'string' || password.length < 8 || password.length > 200) throw bad('La contraseña nueva debe tener al menos 8 caracteres.');
  if (limited('r:' + req.ip, 20)) throw new HttpError(429, 'Demasiados intentos. Intenta de nuevo en una hora.');
  const hash = await hashPassword(password);
  const client = await pool.connect();
  try {
    await client.query('begin');
    // borrar-y-devolver consume el enlace de forma atómica: sirve una sola vez
    const { rows } = await client.query('delete from password_resets where token_hash = $1 and expires_at > now() returning user_id', [sha256(token)]);
    if (!rows[0]) { await client.query('rollback'); throw new HttpError(400, 'El enlace venció o ya se usó. Pide uno nuevo.'); }
    await client.query('update admin_users set password_hash = $1 where id = $2', [hash, rows[0].user_id]);
    await client.query('delete from sessions where user_id = $1', [rows[0].user_id]);
    await client.query('delete from password_resets where user_id = $1', [rows[0].user_id]);
    await client.query('commit');
  } catch (e) { await client.query('rollback').catch(() => {}); throw e; } finally { client.release(); }
  res.json({ ok: true });
});

// ── administración (requiere sesión) ─────────────────────────────────────────
const admin = express.Router();
admin.use(auth);

admin.get('/menu', async (req, res) => res.json({ categories: await loadMenu(true) }));

admin.post('/password', async (req, res) => {
  const { current, next } = req.body || {};
  if (typeof next !== 'string' || next.length < 8 || next.length > 200) throw bad('La contraseña nueva debe tener al menos 8 caracteres.');
  const { rows } = await pool.query('select password_hash from admin_users where id = $1', [req.user.id]);
  if (!(await verifyPassword(String(current || ''), rows[0].password_hash))) throw new HttpError(403, 'La contraseña actual no es correcta.');
  await pool.query('update admin_users set password_hash = $1 where id = $2', [await hashPassword(next), req.user.id]);
  await pool.query('delete from sessions where user_id = $1 and token_hash <> $2', [req.user.id, req.tokenHash]);
  res.json({ ok: true });
});

admin.post('/categories', async (req, res) => {
  const o = parseCategory(req.body || {}, false);
  if (!('sort' in o)) o.sort = (await pool.query('select coalesce(max(sort), 0) + 10 as n from categories where screen = $1', [o.screen])).rows[0].n;
  const q = insertSql('categories', o);
  res.status(201).json((await pool.query(q)).rows[0]);
});

admin.patch('/categories/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) throw bad('Categoría no válida.');
  const o = parseCategory(req.body || {}, true);
  if (o.screen) {   // si cambia de pantalla, va al final de la nueva
    const cur = (await pool.query('select screen from categories where id = $1', [id])).rows[0];
    if (cur && cur.screen !== o.screen && !('sort' in o)) o.sort = (await pool.query('select coalesce(max(sort), 0) + 10 as n from categories where screen = $1', [o.screen])).rows[0].n;
  }
  const { rows } = await pool.query(updateSql('categories', o, id));
  if (!rows[0]) throw new HttpError(404, 'La categoría no existe.');
  res.json(rows[0]);
});

admin.delete('/categories/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) throw bad('Categoría no válida.');
  const imgs = (await pool.query('select image_url from products where category_id = $1 and image_url is not null', [id])).rows;
  const { rowCount } = await pool.query('delete from categories where id = $1', [id]);   // los productos se van en cascada
  if (!rowCount) throw new HttpError(404, 'La categoría no existe.');
  for (const r of imgs) await dropUpload(r.image_url);
  res.json({ ok: true });
});

const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

admin.post('/products', async (req, res) => {
  const o = parseProduct(req.body || {}, false);
  if (!('sort' in o)) o.sort = (await pool.query('select coalesce(max(sort), 0) + 10 as n from products where category_id = $1', [o.category_id])).rows[0].n;
  const { rows } = await pool.query(insertSql('products', o));
  res.status(201).json(rows[0]);
});

admin.patch('/products/:id', async (req, res) => {
  const id = req.params.id;
  if (!uuidRe.test(id)) throw bad('Producto no válido.');
  const o = parseProduct(req.body || {}, true);
  const before = (await pool.query('select category_id, image_url from products where id = $1', [id])).rows[0];
  if (!before) throw new HttpError(404, 'El producto no existe.');
  if (o.category_id && o.category_id !== before.category_id && !('sort' in o)) {   // cambia de categoría: va al final
    o.sort = (await pool.query('select coalesce(max(sort), 0) + 10 as n from products where category_id = $1', [o.category_id])).rows[0].n;
  }
  const { rows } = await pool.query(updateSql('products', o, id));
  if ('image_url' in o && before.image_url && before.image_url !== o.image_url) await dropUpload(before.image_url);
  res.json(rows[0]);
});

admin.delete('/products/:id', async (req, res) => {
  const id = req.params.id;
  if (!uuidRe.test(id)) throw bad('Producto no válido.');
  const { rows } = await pool.query('delete from products where id = $1 returning image_url', [id]);
  if (!rows[0]) throw new HttpError(404, 'El producto no existe.');
  await dropUpload(rows[0].image_url);
  res.json({ ok: true });
});

// reordenar: [{id, sort}, ...] en una sola transacción
admin.post('/reorder', async (req, res) => {
  const { table, items } = req.body || {};
  if (!['products', 'categories'].includes(table)) throw bad('Tabla no válida.');
  if (!Array.isArray(items) || !items.length || items.length > 500) throw bad('Lista no válida.');
  for (const it of items) {
    const idOk = table === 'products' ? typeof it.id === 'string' && uuidRe.test(it.id) : Number.isInteger(it.id);
    if (!idOk || !Number.isInteger(it.sort)) throw bad('Lista no válida.');
  }
  const client = await pool.connect();
  try {
    await client.query('begin');
    for (const it of items) await client.query(`update ${table} set sort = $1 where id = $2`, [it.sort, it.id]);
    await client.query('commit');
  } catch (e) { await client.query('rollback').catch(() => {}); throw e; } finally { client.release(); }
  res.json({ ok: true });
});

admin.post('/upload', upload.single('file'), async (req, res) => {
  if (!req.file) throw bad('No llegó ninguna foto.');
  const ext = sniffImage(req.file.buffer);
  if (!ext) throw bad('El archivo no es una imagen válida (JPG, PNG o WebP).');
  const name = `${crypto.randomUUID()}.${ext}`;
  await fs.promises.writeFile(path.join(UPLOAD_DIR, name), req.file.buffer, { mode: 0o644 });
  res.status(201).json({ url: '/uploads/' + name });
});

// si la foto se subió pero el producto no se pudo guardar, el panel la descarta
admin.post('/upload/discard', async (req, res) => { await dropUpload(String(req.body?.url || '')); res.json({ ok: true }); });

app.use('/api/admin', admin);
app.use('/api', (req, res, next) => next(new HttpError(404, 'No encontrado')));

// ── archivos estáticos ───────────────────────────────────────────────────────
// En producción nginx sirve el sitio y /uploads; esto es respaldo y para desarrollo local.
app.use('/uploads', express.static(UPLOAD_DIR, { maxAge: '365d', immutable: true, index: false, dotfiles: 'deny' }));
if (STATIC_DIR) app.use(express.static(STATIC_DIR, { extensions: ['html'] }));

// ── errores ──────────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {   // eslint-disable-line no-unused-vars
  if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
  if (err.code === 'LIMIT_FILE_SIZE') return res.status(413).json({ error: 'La foto es demasiado grande (máx. 6 MB).' });
  if (err.type === 'entity.parse.failed' || err.type === 'entity.too.large') return res.status(400).json({ error: 'Solicitud no válida.' });
  if (err.code === '23503') return res.status(400).json({ error: 'La categoría no existe.' });
  if (err.code === '23514' || err.code === '22P02') return res.status(400).json({ error: 'Datos no válidos.' });
  console.error(err);
  res.status(500).json({ error: 'Error interno. Intenta de nuevo.' });
});

setInterval(() => {
  pool.query('delete from sessions where expires_at < now()').catch(() => {});
  pool.query('delete from password_resets where expires_at < now()').catch(() => {});
}, 3600_000).unref();

const server = app.listen(PORT, '127.0.0.1', () => console.log(`Bambú API en http://127.0.0.1:${PORT}`));
for (const sig of ['SIGTERM', 'SIGINT']) process.on(sig, () => server.close(() => pool.end().then(() => process.exit(0))));
