'use strict';
// Envío de correo. Dos modos, según el archivo de configuración:
//
// 1) DIRECTO desde este servidor (sin proveedor), firmado con DKIM:
//    { "mode": "direct", "from": "El Bambú <no-reply@elbamburestaurante.com>",
//      "helo": "srv1937320.hstgr.cloud",
//      "dkim": { "selector": "mail", "keyFile": "/var/lib/bambu/dkim.key" },
//      "siteUrl": "https://elbamburestaurante.com" }
//    Requiere en el DNS: SPF (ip4 de este servidor), DKIM (clave pública) y DMARC.
//
// 2) A TRAVÉS DE UN PROVEEDOR SMTP (Resend, Brevo, Mailgun, Hostinger, Gmail...):
//    { "host": "smtp.resend.com", "port": 465, "user": "resend", "pass": "...",
//      "from": "El Bambú <no-reply@elbamburestaurante.com>", "siteUrl": "https://..." }
//
// El archivo es SMTP_FILE (por defecto <carpeta de fotos>/../smtp.json) y se lee en cada envío:
// cambiarlo no requiere reiniciar. Las variables SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS,
// MAIL_FROM y SITE_URL tienen prioridad sobre el archivo.
const fs = require('fs');
const path = require('path');
const dns = require('dns').promises;
const nodemailer = require('nodemailer');

const FILE = process.env.SMTP_FILE ||
  path.join(process.env.UPLOAD_DIR ? path.dirname(path.resolve(process.env.UPLOAD_DIR)) : __dirname, 'smtp.json');

function fileConfig() {
  try { return JSON.parse(fs.readFileSync(FILE, 'utf8')); }
  catch (e) { if (e.code !== 'ENOENT') console.warn('[mail] no se pudo leer', FILE, e.message); return {}; }
}

function loadConfig() {
  const c = fileConfig();
  const from = process.env.MAIL_FROM || c.from;
  if (!from) return null;
  const host = process.env.SMTP_HOST || c.host;
  if (host) {
    return { mode: 'relay', from, host, port: +(process.env.SMTP_PORT || c.port || 465),
      user: process.env.SMTP_USER || c.user, pass: process.env.SMTP_PASS || c.pass,
      secure: process.env.SMTP_SECURE ? process.env.SMTP_SECURE === 'true' : c.secure };
  }
  if (c.mode === 'direct' && c.dkim && c.dkim.keyFile) {
    let privateKey;
    try { privateKey = fs.readFileSync(c.dkim.keyFile, 'utf8'); } catch (e) { console.warn('[mail] no se pudo leer la clave DKIM:', e.message); return null; }
    return { mode: 'direct', from, helo: c.helo, selector: c.dkim.selector || 'mail', privateKey,
      // solo para pruebas: enviar a un servidor fijo en vez de buscar el MX del destinatario
      testHost: c.testHost, testPort: c.testPort };
  }
  return null;
}

const isConfigured = () => !!loadConfig();

// Dirección pública del sitio para armar los enlaces del correo. Es fija (no sale del header Host)
// para que nadie pueda hacer que el enlace de recuperación apunte a otro sitio.
const siteUrl = () => (process.env.SITE_URL || fileConfig().siteUrl || 'https://elbamburestaurante.com').replace(/\/+$/, '');

const domainOf = addr => String(addr).replace(/^.*</, '').replace(/>.*$/, '').split('@').pop().trim().toLowerCase();
const timeouts = { connectionTimeout: 10_000, greetingTimeout: 10_000, socketTimeout: 20_000 };

async function sendRelay(cfg, msg) {
  const transport = nodemailer.createTransport({
    host: cfg.host, port: cfg.port, secure: cfg.secure ?? cfg.port === 465,
    auth: cfg.user ? { user: cfg.user, pass: cfg.pass } : undefined, ...timeouts,
  });
  return transport.sendMail({ from: cfg.from, ...msg });
}

// Entrega directa: se busca el MX del destinatario y se le entrega el correo firmado con DKIM.
async function sendDirect(cfg, msg) {
  let targets;
  if (cfg.testHost) targets = [{ host: cfg.testHost, port: cfg.testPort || 25 }];
  else {
    const domain = domainOf(msg.to);
    try { targets = (await dns.resolveMx(domain)).sort((a, b) => a.priority - b.priority).slice(0, 3).map(m => ({ host: m.exchange, port: 25 })); }
    catch { targets = [{ host: domain, port: 25 }]; }
  }
  let lastErr;
  for (const t of targets) {
    try {
      const transport = nodemailer.createTransport({
        host: t.host, port: t.port, secure: false, name: cfg.helo || undefined,
        tls: { rejectUnauthorized: false },   // entre servidores de correo el certificado del MX rara vez coincide: se cifra de forma oportunista
        dkim: { domainName: domainOf(cfg.from), keySelector: cfg.selector, privateKey: cfg.privateKey },
        ...timeouts,
      });
      return await transport.sendMail({ from: cfg.from, ...msg });
    } catch (e) { lastErr = e; }
  }
  throw lastErr || new Error('sin servidor de correo de destino');
}

async function sendMail({ to, subject, text, html }) {
  const cfg = loadConfig();
  if (!cfg) throw new Error('correo no configurado');
  const msg = { to, subject, text, html };
  return cfg.mode === 'direct' ? sendDirect(cfg, msg) : sendRelay(cfg, msg);
}

module.exports = { isConfigured, sendMail, siteUrl };
