#!/usr/bin/env node
// Ponte da Bina — Central Gás
// Captura o caller-ID e envia pro Supabase (RPC ingest_bina). Duas fontes:
//   1) BraiD (PADRÃO) — o PlugIn BraiD Repeaters (PC principal da loja) lê a bina no
//      áudio analógico das linhas e reenvia por UDP. Basta cadastrar o IP deste PC em
//      "Configurações de IP's / Enviar para mais IP's" do BraiD, porta BRAID_PORT.
//   2) Syslog do HT814 — só funciona com o HT814 na mesma rede (hoje não está).
// O telefone NUNCA depende disto: se a ponte cair, a ligação acontece igual; só não aparece na tela.
//
// Uso:
//   node ponte.js                 -> escuta BraiD + syslog e ingere as chamadas
//   LEARN=1 node ponte.js         -> MODO APRENDIZADO: só mostra cru o que chega (pra achar o formato)
//   node ponte.js --simular 31999998888 [L4]   -> envia uma chamada de teste (testa a corrente sem telefone)
//
// Sem dependências externas — só Node 18+ (usa fetch, dgram nativos).

import dgram from 'node:dgram'
import process from 'node:process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// carrega o .env da pasta do script (sem dependência externa)
try {
  const dir = path.dirname(fileURLToPath(import.meta.url))
  const envPath = path.join(dir, '.env')
  if (fs.existsSync(envPath)) {
    for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
      const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/)
      if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '')
    }
  }
} catch { /* segue sem .env */ }

const cfg = {
  url: (process.env.SUPABASE_URL || '').replace(/\/$/, ''),
  anon: process.env.SUPABASE_ANON_KEY || '',
  token: process.env.INGEST_TOKEN || '',
  port: parseInt(process.env.SYSLOG_PORT || '514', 10),
  // porta onde o BraiD entrega os eventos ("Enviar para mais IP's"). 0 = desliga.
  braidPort: parseInt(process.env.BRAID_PORT || '6590', 10),
  learn: process.env.LEARN === '1',
  // regex p/ extrair o número do caller-ID no syslog. Default = cabeçalho From do INVITE SIP.
  // AJUSTE depois de ver o formato real no LEARN (o grupo 1 é o número).
  cidRegex: process.env.CID_REGEX || 'From:[^\\r\\n]*?sip:\\+?(\\d{8,})@',
  // opcional: regex pra descobrir a linha no syslog (ex.: conta SIP / porta). Vazio = sem linha.
  lineRegex: process.env.LINE_REGEX || '',
  // ignora a mesma chamada repetida (BraiD e syslog mandam vários pacotes por ligação)
  debounceMs: parseInt(process.env.DEBOUNCE_MS || '6000', 10),
}

const ts = () => new Date().toISOString().replace('T', ' ').slice(0, 19)
const log = (...a) => console.log(ts(), ...a)

// ---------- envio pro Supabase ----------
async function enviar(numero, linha) {
  if (!cfg.url || !cfg.anon || !cfg.token) throw new Error('configure SUPABASE_URL / SUPABASE_ANON_KEY / INGEST_TOKEN no .env')
  const res = await fetch(`${cfg.url}/rest/v1/rpc/ingest_bina`, {
    method: 'POST',
    headers: { apikey: cfg.anon, Authorization: `Bearer ${cfg.anon}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_token: cfg.token, p_numero: numero, p_linha: linha || null }),
  })
  const txt = await res.text()
  if (!res.ok) throw new Error(`HTTP ${res.status} ${txt}`)
  try { const j = JSON.parse(txt); return Array.isArray(j) ? j[0] : j } catch { return null }
}

// ---------- fila simples de retry (não perde chamada se a nuvem piscar) ----------
const fila = []
let timerFila = null
function enfileirar(numero, linha) {
  fila.push({ numero, linha, tentativas: 0 })
  if (!timerFila) timerFila = setInterval(processarFila, 5000)
}
async function processarFila() {
  if (!fila.length) { clearInterval(timerFila); timerFila = null; return }
  const item = fila.shift()
  try { const r = await enviar(item.numero, item.linha); log('reenviada da fila:', item.numero, '-> #' + (r?.numero ?? '?')) }
  catch (e) { item.tentativas++; if (item.tentativas < 20) fila.push(item); else log('DESCARTADA após 20 tentativas:', item.numero, e.message) }
}

// ---------- dedupe ----------
const recentes = new Map()
function repetida(key) {
  const now = Date.now()
  const last = recentes.get(key) || 0
  recentes.set(key, now)
  if (recentes.size > 1000) for (const [k, t] of recentes) if (now - t > 120000) recentes.delete(k)
  return now - last < cfg.debounceMs
}

function extrair(texto, regexStr) {
  if (!regexStr) return null
  try { const m = texto.match(new RegExp(regexStr, 'i')); return m && m[1] ? m[1].replace(/\D/g, '') : null } catch { return null }
}

function ingerir(numero, linha, fonte) {
  const key = `${linha || ''}:${numero.slice(-8)}`
  if (repetida(key)) return
  log(`chamada detectada (${fonte}):`, numero, linha ? `(linha ${linha})` : '')
  enviar(numero, linha)
    .then((r) => log('-> ingerida #' + (r?.numero ?? '?'), r?.cliente_id ? '(cliente casado)' : '(não cadastrado)'))
    .catch((e) => { log('falha no envio, vai pra fila:', e.message); enfileirar(numero, linha) })
}

// ---------- modo simular ----------
const args = process.argv.slice(2)
if (args[0] === '--simular') {
  const numero = (args[1] || '31999990000').replace(/\D/g, '')
  const linha = args[2] || 'L1'
  log('simulando chamada', numero, 'linha', linha)
  enviar(numero, linha)
    .then((r) => { log('OK -> chamada #' + (r?.numero ?? '?'), 'cliente:', r?.cliente_id || '(não cadastrado)'); process.exit(0) })
    .catch((e) => { console.error('FALHOU:', e.message); process.exit(1) })
} else {
  iniciarBraid()
  iniciarSyslog()
}

// ---------- BraiD (a mesma fonte de bina que o JBFER usa hoje) ----------
// Pacotes UDP de 150 bytes: parte útil ASCII "&&L1_INDEX_PHONE->1995878395@" + lixo binário.
// Eventos por chamada (em duplicata): CALLER_DTMF/FSK, NUMBER_FORMAT_*, INDEX_PHONE,
// DETECT_PHONE, RING_COUNT. Usamos INDEX_PHONE/CALLER_* (dígitos puros); NUMBER_FORMAT e
// DETECT vêm com o TIPO da chamada colado na frente (3=celular) e sujariam o número.
// Quirk conhecido: a captura por áudio derruba o 1º dígito do DDD — não afeta, o match
// do cliente é pelos 8 últimos dígitos.
function iniciarBraid() {
  if (!cfg.braidPort) return
  const sock = dgram.createSocket('udp4')
  sock.on('message', (buf, rinfo) => {
    const texto = buf.toString('latin1').replace(/[^\x20-\x7e]/g, '')
    if (cfg.learn) { console.log(`--- BraiD de ${rinfo.address} ---\n${texto}\n`); return }
    const m = texto.match(/&&L(\d+)_(?:INDEX_PHONE|CALLER_DTMF|CALLER_FSK)->([0-9()\- ]+)@/)
    if (!m) return
    const numero = m[2].replace(/\D/g, '')
    if (numero.length < 8) return
    ingerir(numero, 'L' + m[1], 'BraiD')
  })
  sock.on('error', (e) => log('erro no socket BraiD:', e.message))
  sock.bind(cfg.braidPort, () => {
    log(`ouvindo BraiD em udp/${cfg.braidPort}` + (cfg.learn ? '  [MODO APRENDIZADO — só mostra o que chega]' : ''))
    if (!cfg.learn && (!cfg.url || !cfg.token)) log('ATENÇÃO: .env incompleto — vou detectar mas não vou conseguir enviar.')
  })
}

// ---------- syslog (HT814 — só com o HT814 na mesma rede) ----------
function iniciarSyslog() {
  if (!cfg.port) return
  const sock = dgram.createSocket('udp4')
  sock.on('message', (buf, rinfo) => {
    const raw = buf.toString('utf8')
    if (cfg.learn) { console.log('--- syslog de', rinfo.address, '---\n' + raw + '\n'); return }
    const numero = extrair(raw, cfg.cidRegex)
    if (!numero) return
    ingerir(numero, extrair(raw, cfg.lineRegex), 'syslog')
  })
  sock.on('error', (e) => log('erro no socket syslog:', e.message))
  sock.bind(cfg.port, () => log(`ouvindo syslog em udp/${cfg.port}` + (cfg.learn ? '  [MODO APRENDIZADO — só mostra o que chega]' : '')))
}
