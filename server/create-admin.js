'use strict';
// Crea un usuario del panel, o cambia su contraseña si ya existe.
//   node create-admin.js <usuario> [contraseña]
// Sin contraseña genera una aleatoria y la imprime una sola vez.
const crypto = require('crypto');
const { Pool } = require('pg');
const { hashPassword } = require('./password');

(async () => {
  const [username, given] = process.argv.slice(2);
  if (!username || !process.env.DATABASE_URL) {
    console.error('Uso: DATABASE_URL=... node create-admin.js <usuario> [contraseña]');
    process.exit(1);
  }
  if (given && given.length < 8) { console.error('La contraseña debe tener al menos 8 caracteres.'); process.exit(1); }
  const password = given || crypto.randomBytes(12).toString('base64url');
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const hash = await hashPassword(password);
  const { rows } = await pool.query(
    `insert into admin_users (username, password_hash) values ($1, $2)
     on conflict (lower(username)) do update set password_hash = excluded.password_hash
     returning id, (xmax = 0) as created`, [username.trim(), hash]);
  await pool.query('delete from sessions where user_id = $1', [rows[0].id]);
  console.log(`${rows[0].created ? 'Usuario creado' : 'Contraseña actualizada'}: ${username.trim()}`);
  if (!given) console.log(`Contraseña: ${password}`);
  await pool.end();
})().catch(e => { console.error(e.message); process.exit(1); });
