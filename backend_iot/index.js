require('dotenv').config();
const mqtt = require('mqtt');
const mysql = require('mysql2/promise');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');

const JWT_SECRET  = process.env.JWT_SECRET || 'watersmart_jwt_secret_2024_change_in_prod';
const JWT_EXPIRES = '30d';

// ═══════════════════════════════════════════════════════════════════════════════
// ✉ EMAIL ALERTS (Nodemailer + Gmail SMTP)
// Configura EMAIL_APP_PASS en .env con tu Google App Password
// ═══════════════════════════════════════════════════════════════════════════════
const emailTransporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_APP_PASS,
    },
});

// Cooldown por tipo: no spamear el mismo tipo de alerta más de 1 vez cada 5 min
const emailCooldowns = {};
const EMAIL_COOLDOWN_MS = 5 * 60 * 1000;

async function enviarAlertaEmail(tipo, asunto, cuerpoHtml) {
    if (!process.env.EMAIL_APP_PASS || process.env.EMAIL_APP_PASS === 'REEMPLAZA_CON_TU_APP_PASSWORD') {
        console.log(`ℹ️ [Email] App Password no configurada — omitiendo alerta: ${tipo}`);
        return;
    }
    const ahora = Date.now();
    if (emailCooldowns[tipo] && ahora - emailCooldowns[tipo] < EMAIL_COOLDOWN_MS) {
        console.log(`⏸️ [Email] Cooldown activo para ${tipo} — omitiendo`);
        return;
    }
    emailCooldowns[tipo] = ahora;
    try {
        await emailTransporter.sendMail({
            from: `"WaterSmart Alerts" <${process.env.EMAIL_USER}>`,
            to: process.env.EMAIL_TO,
            subject: asunto,
            html: `
                <div style="font-family:sans-serif;background:#0d1117;color:#e6edf3;padding:32px;border-radius:12px">
                  <div style="border-left:4px solid #00e5ff;padding-left:16px;margin-bottom:24px">
                    <h2 style="color:#00e5ff;margin:0;letter-spacing:2px">WATER SMART SYSTEM</h2>
                    <p style="color:#8b949e;margin:4px 0">Alerta Automática del Sistema</p>
                  </div>
                  ${cuerpoHtml}
                  <hr style="border-color:#21262d;margin:24px 0">
                  <p style="color:#8b949e;font-size:12px">
                    ⏰ ${new Date().toLocaleString('es-VE', { timeZone: 'America/Caracas' })} (VET)
                  </p>
                </div>`,
        });
        console.log(`✉ [Email] Alerta enviada: ${asunto}`);
    } catch (err) {
        console.error(`❌ [Email] Error enviando alerta: ${err.message}`);
    }
}


// Connected Flutter Web clients
const wsClients = new Set();

// --- Configuración de Base de Datos (Aiven MySQL) ---
const dbConfig = {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    ssl: {
        ca: fs.readFileSync(path.join(__dirname, 'ca.pem'))
    }
};

let pool;

async function initDB() {
    try {
        console.log('⏳ Inicializando pool de conexiones a MySQL...');
        pool = mysql.createPool(dbConfig);
        const connection = await pool.getConnection();
        console.log('✅ Conectado exitosamente a Aiven MySQL vía Pool');
        connection.release();

        // ── fault_events (tabla existente) ───────────────────────────────────────
        await pool.execute(`
            CREATE TABLE IF NOT EXISTS fault_events (
                id            INT AUTO_INCREMENT PRIMARY KEY,
                fault_type    VARCHAR(100) NOT NULL,
                fuente_activa VARCHAR(20)  DEFAULT NULL,
                presion       FLOAT        DEFAULT NULL,
                flujo         FLOAT        DEFAULT NULL,
                nivel_tank    FLOAT        DEFAULT NULL,
                detalles      TEXT         DEFAULT NULL,
                fecha         TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
                sistema_id    INT          DEFAULT 1,
                INDEX idx_fault_type (fault_type),
                INDEX idx_fecha (fecha)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);
        console.log('✅ Tabla fault_events lista');

        // ── Multi-tenancy: sistemas ───────────────────────────────────────────────
        await pool.execute(`
            CREATE TABLE IF NOT EXISTS sistemas (
                id           INT AUTO_INCREMENT PRIMARY KEY,
                nombre       VARCHAR(100) NOT NULL,
                descripcion  TEXT,
                ubicacion    VARCHAR(200),
                timezone     VARCHAR(50) DEFAULT 'America/Caracas',
                topic_prefix VARCHAR(50) DEFAULT 'agua_iot',
                activo       BOOLEAN DEFAULT TRUE,
                creado_en    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);

        // ── Multi-tenancy: usuarios ───────────────────────────────────────────────
        await pool.execute(`
            CREATE TABLE IF NOT EXISTS usuarios (
                id            INT AUTO_INCREMENT PRIMARY KEY,
                nombre        VARCHAR(100) NOT NULL,
                email         VARCHAR(150) NOT NULL UNIQUE,
                password_hash VARCHAR(255) NOT NULL,
                rol_global    ENUM('admin','operador','viewer') DEFAULT 'operador',
                activo        BOOLEAN DEFAULT TRUE,
                creado_en     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);

        // ── Multi-tenancy: permisos usuario <-> sistema ───────────────────────────
        await pool.execute(`
            CREATE TABLE IF NOT EXISTS usuario_sistema (
                usuario_id INT NOT NULL,
                sistema_id INT NOT NULL,
                rol        ENUM('admin','operador','viewer') DEFAULT 'operador',
                PRIMARY KEY (usuario_id, sistema_id),
                FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
                FOREIGN KEY (sistema_id) REFERENCES sistemas(id)  ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);
        console.log('✅ Tablas multi-tenant listas (sistemas, usuarios, usuario_sistema)');

        // ── Seed: sistema #1 ──────────────────────────────────────────────────────
        await pool.execute(`
            INSERT IGNORE INTO sistemas (id, nombre, descripcion, ubicacion, topic_prefix)
            VALUES (1, 'WaterSmart Venezuela', 'Sistema principal', 'Venezuela', 'agua_iot')
        `);

        // ── Seed: usuario admin ────────────────────────────────────────────────────
        const [adminRows] = await pool.execute(
            'SELECT id FROM usuarios WHERE email = ?',
            ['admin@watersmart.local']
        );
        if (adminRows.length === 0) {
            const hash = await bcrypt.hash('WaterSmart2024', 12);
            const [result] = await pool.execute(
                `INSERT INTO usuarios (nombre, email, password_hash, rol_global)
                 VALUES ('Administrador', 'admin@watersmart.local', ?, 'admin')`,
                [hash]
            );
            await pool.execute(
                `INSERT IGNORE INTO usuario_sistema (usuario_id, sistema_id, rol)
                 VALUES (?, 1, 'admin')`,
                [result.insertId]
            );
            console.log('✅ Usuario admin creado: admin@watersmart.local / WaterSmart2024');
        } else {
            console.log('ℹ️ Usuario admin ya existe en DB');
        }

    } catch (error) {
        console.error('❌ Error inicializando DB:', error.message);
        if (error.code === 'ENOENT') {
            console.error('⚠️ ATENCIÓN: No se encontró el archivo ca.pem.');
            console.error('Descárgalo de Aiven y colócalo en:', __dirname);
        }
        console.log('⏳ Reintentando conexión a DB en 5 segundos...');
        setTimeout(initDB, 5000);
    }
}

// ── JWT helpers ───────────────────────────────────────────────────────────────
function signToken(payload) {
    return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES });
}
function verifyToken(token) {
    try { return jwt.verify(token, JWT_SECRET); } catch { return null; }
}
function extractToken(req) {
    const auth = req.headers['authorization'] || '';
    return auth.startsWith('Bearer ') ? auth.slice(7) : null;
}

// ── GAP 2: Guardar evento de falla en MySQL ───────────────────────────────────
async function guardarFaultEvent(tipo, datos = {}) {
    if (!pool) return;
    try {
        await pool.execute(
            `INSERT INTO fault_events (fault_type, fuente_activa, presion, flujo, nivel_tank, detalles)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [
                tipo,
                datos.fuente || getFuenteActiva() || null,
                sistemaEstado.presion  || null,
                sistemaEstado.flujo    || null,
                datos.nivel            || null,
                JSON.stringify(datos),
            ]
        );
    } catch (err) {
        console.warn(`⚠️ [fault_events] No se pudo guardar evento: ${err.message}`);
    }
}

// ── GAP 6: Buffer circular de lecturas de presión/flujo (derivada) ────────────
const BUFFER_SIZE = 10;
const pressureBuffer = [];  // [{value, ts}]
const flowBuffer     = [];  // [{value, ts}]
const levelCalleBuf  = [];  // [{value, ts}] para correlación nivel-flujo
const levelLluviaBuf = [];

function pushBuffer(buf, value) {
    buf.push({ value, ts: Date.now() });
    if (buf.length > BUFFER_SIZE) buf.shift();
}

// Calcula la tasa de cambio (unidad/segundo) entre el primer y último punto del buffer.
function getRateOfChange(buf) {
    if (buf.length < 3) return 0;
    const oldest = buf[0];
    const newest = buf[buf.length - 1];
    const deltaT = (newest.ts - oldest.ts) / 1000; // segundos
    if (deltaT <= 0) return 0;
    return (newest.value - oldest.value) / deltaT;
}

initDB();


// --- Configuración e Inicialización de MQTT (HiveMQ Cloud) ---
const mqttUrl = `mqtts://${process.env.MQTT_HOST}:${process.env.MQTT_PORT}`;
const mqttOptions = {
    clientId: 'iot_bridge_' + Math.random().toString(16).slice(2, 8),
    username: process.env.MQTT_USER,
    password: process.env.MQTT_PASS,
    reconnectPeriod: 5000,
    rejectUnauthorized: true
};

console.log(`⏳ Intentando conectar a MQTT: ${mqttUrl}...`);
const client = mqtt.connect(mqttUrl, mqttOptions);

client.on('connect', () => {
    console.log('✅ Conectado a HiveMQ Cloud con éxito');

    // ── Limpiar mensajes retenidos de TODOS los actuadores al arrancar ───────────
    // Publicar payload vacío con retain:true elimina el mensaje del broker.
    // Esto evita que lleguen estados viejos (ej: bomba=1) al reconectarse.
    const topicosALimpiar = [
        'agua_iot/calidad/turbidez',
        'agua_iot/actuadores/bomba',
        'agua_iot/actuadores/solenoide',
        'agua_iot/actuadores/bomba_calle',
        'agua_iot/actuadores/solenoide_calle',
        'agua_iot/actuadores/bomba_lluvia',
        'agua_iot/actuadores/solenoide_lluvia',
    ];
    topicosALimpiar.forEach(t => {
        client.publish(t, '', { retain: true, qos: 1 });
    });
    console.log('🧹 Mensajes retenidos de actuadores limpiados del broker');

    const topics = [
        // ── Tópicos Legacy (simulador.js) ────────────────────────────────────
        'agua_iot/sensores_presion/1',
        'agua_iot/sensores_presion/2',
        'agua_iot/nivel/lectura',
        'agua_iot/nivel/lectura_2',
        'agua_iot/actuadores/bomba',
        'agua_iot/actuadores/solenoide',
        // ── Tópicos ESP32 Tanques (hardware real) ─────────────────────────────
        'agua_iot/tanque_lluvia/nivel',
        'agua_iot/tanque_calle/nivel',
        'agua_iot/tanque_lluvia/sensor_0',
        'agua_iot/tanque_lluvia/sensor_50',
        'agua_iot/tanque_lluvia/sensor_100',
        'agua_iot/tanque_calle/sensor_0',
        'agua_iot/tanque_calle/sensor_50',
        'agua_iot/tanque_calle/sensor_100',
        // ── Tópicos ESP32 Presión y Flujo (hardware real) ──────────────────
        'agua_iot/sensores/presion',
        'agua_iot/sensores/flujo',
        // ── Tópicos ESP32 Actuadores (hardware real) ────────────────────
        'agua_iot/actuadores/bomba_calle',
        'agua_iot/actuadores/solenoide_calle',
        'agua_iot/actuadores/bomba_lluvia',
        'agua_iot/actuadores/solenoide_lluvia',
        // ── Heartbeat ESP32s (Regla 11) ─────────────────────────────────
        'agua_iot/heartbeat/control_calle',
        'agua_iot/heartbeat/control_lluvia',
    ];

    client.subscribe(topics, (err) => {
        if (err) {
            console.error('❌ Error al suscribirse a los tópicos MQTT:', err);
        } else {
            console.log('📡 Suscrito correctamente a los tópicos:', topics.join(', '));
        }
    });
});

client.on('error', (error) => {
    console.error('❌ Error en conexión MQTT:', error);
});

client.on('offline', () => {
    console.log('⚠️ Cliente MQTT Offline. Intentando reconectar...');
});


// --- Mapeo de Tópicos a IDs de Componente ---
const TOPIC_MAP = {
    // ── Sensores y actuadores (legacy / simulador) ────────────────────────────
    'agua_iot/sensores_presion/1': 1,  // Presión (tópico legacy)
    'agua_iot/sensores_presion/2': 2,  // Flujo   (tópico legacy)
    'agua_iot/nivel/lectura':      3,  // Nivel Tanque Lluvia  (tópico legacy)
    'agua_iot/nivel/lectura_2':    4,  // Nivel Tanque Calle   (tópico legacy)
    'agua_iot/actuadores/bomba':   6,  // Estado Bomba (0/1)
    'agua_iot/actuadores/solenoide': 7, // Estado Solenoide (0/1)
    // ── Tópicos ESP32 hardware real — niveles calculados ─────────────────────
    'agua_iot/tanque_lluvia/nivel': 3,
    'agua_iot/tanque_calle/nivel':  4,
    'agua_iot/sensores/presion':    1,
    'agua_iot/sensores/flujo':      2,
    // ── Tópicos ESP32 hardware real — sensores individuales reed switch ───────
    // Tanque Calle: sensor_0 = vacío, sensor_50 = mitad, sensor_100 = lleno
    'agua_iot/tanque_calle/sensor_0'   : 8,
    'agua_iot/tanque_calle/sensor_50'  : 9,
    'agua_iot/tanque_calle/sensor_100' : 10,
    // Tanque Lluvia: misma lógica
    'agua_iot/tanque_lluvia/sensor_0'  : 11,
    'agua_iot/tanque_lluvia/sensor_50' : 12,
    'agua_iot/tanque_lluvia/sensor_100': 13,
    // ── Actuadores ESP32_WaterSmart_Alan (mismos IDs que legacy) ─────────────
    'agua_iot/actuadores/bomba_calle'      : 6,
    'agua_iot/actuadores/solenoide_calle'  : 7,
    'agua_iot/actuadores/bomba_lluvia'     : 6,
    'agua_iot/actuadores/solenoide_lluvia' : 7,
};

// ═══════════════════════════════════════════════════════════════════════════════
// 🧪 MODO PRUEBA — cuando está activo se saltean TODAS las reglas automáticas.
//           Activár con POST /api/test-mode  { "active": true }
//           Desactivar con  POST /api/test-mode  { "active": false }
// ═══════════════════════════════════════════════════════════════════════════════
let modoPrueba = false;

// ═══════════════════════════════════════════════════════════════════════════════
// 🧠 MOTOR DE REGLAS INTELIGENTES (Backend — actúa incluso sin Flutter abierto)
//
// PRINCIPIO: Si falla la fuente activa → cambiar a la fuente de respaldo.
//            Solo apagar todo si AMBAS fuentes no están disponibles.
// ═══════════════════════════════════════════════════════════════════════════════

const sistemaEstado = {
    // Actuadores (sincronizados por echos MQTT)
    bombaPrincipal: false,   // ← Bomba principal (agua_iot/actuadores/bomba)
    bombaCalle    : false,
    solenoideCalle: false,
    bombaLluvia   : false,
    soleLluvia    : false,
    // Sensores
    presion       : 0,
    flujo         : 0,
    tankCalle     : 0,
    tankLluvia    : 0,
    // Tracking de tiempo para reglas basadas en duración
    flujoZeroDesde   : null,
    presionBajaDesde : null,
    lastFailover     : null,
    failoverCooldownMs: 90000,
    // Umbrales
    MIN_PRESION    : 10,
    MAX_PRESION    : 45,
    MIN_FLUJO_FUGA : 0.5,
    MIN_TANK_NIVEL : 15,
    WINDOW_ROTURA  : 30000,
    WINDOW_PRESION : 20000,
    // ── Heartbeat ESP32s (Regla 11) ────────────────────────────────
    // null = nunca visto, Date = último heartbeat recibido
    lastHeartbeatCalle  : null,
    lastHeartbeatLluvia : null,
    HEARTBEAT_TIMEOUT_MS: 35000,  // 35s sin heartbeat = ESP32 caído
    esp32CalleOnline    : false,  // se pone true al primer heartbeat
    esp32LluviaOnline   : false,
};

// ── Sincronizar estado desde mensajes MQTT ───────────────────────────────────
function syncEstado(topic, valor) {
    if (topic === 'agua_iot/sensores/presion' || topic === 'agua_iot/sensores_presion/1') {
        sistemaEstado.presion = valor;
        pushBuffer(pressureBuffer, valor); // GAP 6: buffer para derivada
    } else if (topic === 'agua_iot/sensores/flujo' || topic === 'agua_iot/sensores_presion/2') {
        sistemaEstado.flujo = valor;
        pushBuffer(flowBuffer, valor);
    } else if (topic === 'agua_iot/tanque_calle/nivel' || topic === 'agua_iot/nivel/lectura_2') {
        sistemaEstado.tankCalle = valor;
        pushBuffer(levelCalleBuf, valor);
    } else if (topic === 'agua_iot/tanque_lluvia/nivel' || topic === 'agua_iot/nivel/lectura') {
        sistemaEstado.tankLluvia = valor;
        pushBuffer(levelLluviaBuf, valor);
    } else if (topic === 'agua_iot/actuadores/bomba_calle')     sistemaEstado.bombaCalle     = valor === 1;
    else if (topic === 'agua_iot/actuadores/solenoide_calle') sistemaEstado.solenoideCalle = valor === 1;
    else if (topic === 'agua_iot/actuadores/bomba_lluvia')    sistemaEstado.bombaLluvia    = valor === 1;
    else if (topic === 'agua_iot/actuadores/solenoide_lluvia') sistemaEstado.soleLluvia    = valor === 1;
    // Bomba principal (standalone) — NO afecta bombaCalle ni bombaLluvia
    else if (topic === 'agua_iot/actuadores/bomba')     sistemaEstado.bombaPrincipal = valor === 1;
    else if (topic === 'agua_iot/actuadores/solenoide') sistemaEstado.solenoideCalle = valor === 1;
}

// ── Publicar comando automático y notificación ───────────────────────────────
function autoComando(topicActuador, valor, razon) {
    console.log(`🤖 AUTO-CMD: ${topicActuador} = ${valor} [${razon}]`);
    client.publish(topicActuador, String(valor), { qos: 1, retain: true });
}

function autoNotificacion(tipo, datos = {}) {
    // GAP 10: Enriquecer con valores numéricos actuales
    const enriched = {
        ...datos,
        _presion     : sistemaEstado.presion,
        _flujo       : sistemaEstado.flujo,
        _tankCalle   : sistemaEstado.tankCalle,
        _tankLluvia  : sistemaEstado.tankLluvia,
        _fuenteActiva: getFuenteActiva(),
    };
    const notif = JSON.stringify({ type: tipo, automated: true, ...enriched });
    client.publish('agua_iot/notificaciones', notif, { qos: 1 });
    console.log(`🔔 AUTO-NOTIF: ${tipo}`, enriched);

    // GAP 2: Persistir evento de falla en MySQL
    guardarFaultEvent(tipo, enriched);

    // ── Disparar email para alertas críticas ──────────────────────────────────
    const s = sistemaEstado;
    if (tipo === 'failover_automatico') {
        enviarAlertaEmail(tipo,
            `⚠️ WaterSmart — Cambio de fuente automático`,
            `<h3 style="color:#ffa500">⚠️ Failover Automático Ejecutado</h3>
             <p>El sistema cambió automáticamente de fuente de agua.</p>
             <table style="width:100%;border-collapse:collapse">
               <tr><td style="color:#8b949e;padding:8px">Razón:</td><td style="color:#e6edf3">${datos.razon || '—'}</td></tr>
               <tr><td style="color:#8b949e;padding:8px">De:</td><td style="color:#e6edf3">${datos.de || '—'}</td></tr>
               <tr><td style="color:#8b949e;padding:8px">A:</td><td style="color:#e6edf3">${datos.a || '—'}</td></tr>
               <tr><td style="color:#8b949e;padding:8px">Presión:</td><td style="color:#e6edf3">${s.presion.toFixed(1)} PSI</td></tr>
               <tr><td style="color:#8b949e;padding:8px">Flujo:</td><td style="color:#e6edf3">${s.flujo.toFixed(2)} L/min</td></tr>
             </table>`);
    } else if (tipo === 'sin_fuente_disponible') {
        enviarAlertaEmail(tipo,
            `🚨 WaterSmart — CRÍTICO: Sistema detenido`,
            `<h3 style="color:#ff4444">🚨 SISTEMA DETENIDO — Sin fuente disponible</h3>
             <p style="color:#ff6b6b">Ambas fuentes de agua han fallado. El sistema está completamente detenido.</p>
             <p><b>Razón:</b> ${datos.razon || '—'}</p>
             <p><b>Tanque Calle:</b> ${s.tankCalle.toFixed(0)}% | <b>Tanque Lluvia:</b> ${s.tankLluvia.toFixed(0)}%</p>
             <p style="color:#ffa500">Se requiere intervención manual inmediata.</p>`);
    } else if (tipo === 'rotura_tuberia') {
        enviarAlertaEmail(tipo,
            `⛔ WaterSmart — Rotura/bloqueo detectado`,
            `<h3 style="color:#ff4444">⛔ Rotura o Bloqueo de Tubería</h3>
             <p>Se detectó una anomalía en la línea de <b>${datos.fuente || '—'}</b>.</p>
             <p><b>Flujo:</b> ${s.flujo.toFixed(2)} L/min (esperado > 0.1) | <b>Presión:</b> ${s.presion.toFixed(1)} PSI</p>`);
    } else if (tipo === 'presion_critica_alta') {
        enviarAlertaEmail(tipo,
            `⚠️ WaterSmart — Presión peligrosa`,
            `<h3 style="color:#ffa500">⚠️ Presión Crítica Alta</h3>
             <p>Se detectó presión por encima del umbral seguro.</p>
             <p><b>Presión:</b> ${datos.presion || s.presion.toFixed(1)} PSI (límite: ${datos.limite || s.MAX_PRESION} PSI)</p>
             <p>La bomba fue detenida automáticamente para proteger las tuberías.</p>`);
    } else if (tipo === 'tanque_vacio') {
        enviarAlertaEmail(tipo,
            `🔴 WaterSmart — Tanque vacío detectado`,
            `<h3 style="color:#ff4444">🔴 Tanque Vacío</h3>
             <p>El sensor físico confirmó que el tanque de <b>${datos.fuente || '—'}</b> está vacío.</p>
             <p>El sistema procedió a conmutar automáticamente si hay fuente de respaldo disponible.</p>`);
    }
}

// ── Determinar fuente activa ─────────────────────────────────────────────────
function getFuenteActiva() {
    if (sistemaEstado.bombaCalle && sistemaEstado.solenoideCalle)   return 'calle';
    if (sistemaEstado.bombaLluvia && sistemaEstado.soleLluvia)      return 'lluvia';
    return null; // Sistema apagado
}

// ── Failover a la otra fuente ────────────────────────────────────────────────
function ejecutarFailover(razon) {
    const ahora = Date.now();
    if (sistemaEstado.lastFailover &&
        ahora - sistemaEstado.lastFailover < sistemaEstado.failoverCooldownMs) {
        console.log(`⏸ Failover bloqueado por cooldown (${Math.round((ahora - sistemaEstado.lastFailover)/1000)}s)`);
        return;
    }

    const fuenteActual = getFuenteActiva();
    if (!fuenteActual) return; // Sistema ya apagado

    const fuenteRespaldo = fuenteActual === 'calle' ? 'lluvia' : 'calle';
    const nivelRespaldo  = fuenteRespaldo === 'lluvia'
        ? sistemaEstado.tankLluvia
        : sistemaEstado.tankCalle;

    if (nivelRespaldo <= sistemaEstado.MIN_TANK_NIVEL) {
        // ── Sin respaldo disponible → apagar todo ────────────────────────
        console.log(`🚨 Sin fuente de respaldo (nivel ${nivelRespaldo}%) — apagando todo`);
        autoComando('agua_iot/actuadores/bomba_calle',      0, razon);
        autoComando('agua_iot/actuadores/solenoide_calle',  0, razon);
        autoComando('agua_iot/actuadores/bomba_lluvia',     0, razon);
        autoComando('agua_iot/actuadores/solenoide_lluvia', 0, razon);
        autoNotificacion('sin_fuente_disponible', { razon });
        return;
    }

    // ── Failover a fuente de respaldo ────────────────────────────────────
    console.log(`🔄 FAILOVER: ${fuenteActual} → ${fuenteRespaldo} | Razón: ${razon}`);

    // Apagar fuente actual
    autoComando(`agua_iot/actuadores/bomba_${fuenteActual}`,      0, razon);
    autoComando(`agua_iot/actuadores/solenoide_${fuenteActual}`,  0, razon);

    // Encender fuente de respaldo
    autoComando(`agua_iot/actuadores/bomba_${fuenteRespaldo}`,     1, razon);
    autoComando(`agua_iot/actuadores/solenoide_${fuenteRespaldo}`, 1, razon);

    autoNotificacion('failover_automatico', {
        de: fuenteActual, a: fuenteRespaldo, razon
    });

    // Reset contadores de tiempo
    sistemaEstado.flujoZeroDesde   = null;
    sistemaEstado.presionBajaDesde = null;
    sistemaEstado.lastFailover     = ahora;
}

// ── Evaluar todas las reglas ─────────────────────────────────────────────────
function evaluarReglasInteligentes(topic) {
    const s   = sistemaEstado;
    const now = Date.now();
    const sistemaActivo = getFuenteActiva() !== null;

    // ── Regla 7: Agua turbia con distribución activa ──────────────────────
    if (s.turbidez > s.MAX_TURBIDEZ) {
        const distribuyendo = s.solenoideCalle || s.soleLluvia;
        if (distribuyendo) {
            console.log(`⛔ Agua turbia (${s.turbidez} NTU) — cerrando solenoides`);
            autoComando('agua_iot/actuadores/solenoide_calle',  0, 'agua_turbia');
            autoComando('agua_iot/actuadores/solenoide_lluvia', 0, 'agua_turbia');
            autoNotificacion('agua_turbia_activa', { turbidez: s.turbidez });
        }
        return; // No evaluar otras reglas si el agua está sucia
    }

    // ── Regla 4: Presión anómala ALTA ─────────────────────────────────────
    if (sistemaActivo && s.presion > s.MAX_PRESION) {
        const fuenteActiva = getFuenteActiva();
        console.log(`⚠️ Presión muy alta (${s.presion} PSI) — deteniendo bomba ${fuenteActiva}`);
        autoComando(`agua_iot/actuadores/bomba_${fuenteActiva}`, 0, 'presion_alta');
        autoNotificacion('presion_critica_alta', { presion: s.presion, fuente: fuenteActiva, limite: s.MAX_PRESION });
        return;
    }

    // ── GAP 6: Tendencia de presión — subida rápida (>3 PSI/s) ──────────
    if (sistemaActivo) {
        const dPdt = getRateOfChange(pressureBuffer); // PSI/segundo
        if (dPdt > 3.0 && s.presion > (s.MAX_PRESION * 0.75)) {
            const fuenteActiva = getFuenteActiva();
            console.log(`⚡ Presión subiendo rápido (${dPdt.toFixed(2)} PSI/s) — pre-alerta en ${fuenteActiva}`);
            autoNotificacion('tendencia_presion_alta', {
                fuente    : fuenteActiva,
                presion   : s.presion,
                tasa_cambio: dPdt.toFixed(2),
                mensaje   : `Presión subiendo ${dPdt.toFixed(1)} PSI/s — posible golpe de ariete`,
            });
        }
    }

    // ── Regla 2: Fuga (flujo activo con sistema apagado) ──────────────────
    if (!sistemaActivo && s.flujo > s.MIN_FLUJO_FUGA) {
        autoNotificacion('fuga_detectada', { flujo: s.flujo });
        return;
    }

    if (!sistemaActivo) return; // Resto de reglas requieren sistema activo

    // ── GAP 7: Correlación nivel-flujo (sensor atascado vs rotura real) ───
    // Si el nivel del tanque activo cae rápido (>2%/min) pero el flujo reporta 0
    // → el sensor de flujo puede estar atascado (no es rotura real).
    const fuenteActiva = getFuenteActiva();
    if (fuenteActiva) {
        const levelBuf = fuenteActiva === 'calle' ? levelCalleBuf : levelLluviaBuf;
        const dNdt = getRateOfChange(levelBuf); // %/segundo
        const dNdtPerMin = dNdt * 60; // %/minuto
        if (dNdtPerMin < -2.0 && s.flujo < 0.05) {
            console.log(`🔧 [Correlación] Nivel cayendo (${dNdtPerMin.toFixed(2)}%/min) pero flujo=0 → posible sensor flujo atascado`);
            autoNotificacion('sensor_flujo_posiblemente_atascado', {
                fuente       : fuenteActiva,
                caida_nivel  : dNdtPerMin.toFixed(2),
                flujo        : s.flujo,
                mensaje      : `Nivel cae ${Math.abs(dNdtPerMin).toFixed(1)}%/min con flujo=0 — verificar sensor de caudal`,
            });
        }
    }

    // ── Regla 1: Rotura de tubería (flujo cero con sistema activo 30s) ────
    const solAbierto = s.solenoideCalle || s.soleLluvia;
    if (solAbierto && s.flujo < 0.1) {
        if (!s.flujoZeroDesde) {
            s.flujoZeroDesde = now;
        } else if (now - s.flujoZeroDesde >= s.WINDOW_ROTURA) {
            const fa = getFuenteActiva();
            const elapsed = Math.round((now - s.flujoZeroDesde) / 1000);
            console.log(`⛔ Flujo cero ${elapsed}s — rotura en ${fa}`);
            autoNotificacion('rotura_tuberia', {
                fuente  : fa,
                elapsed : elapsed,
                presion : s.presion,
                mensaje : `Flujo=0 por ${elapsed}s con bomba activa en ${fa} (Presión: ${s.presion.toFixed(1)} PSI)`,
            });
            ejecutarFailover(`rotura_tuberia_${fa}`);
        }
    } else {
        s.flujoZeroDesde = null; // Reset si flujo volvió
    }

    // ── Regla 3: Presión baja persistente (20s) → failover ────────────────
    if (s.presion > 0 && s.presion < s.MIN_PRESION) {
        if (!s.presionBajaDesde) {
            s.presionBajaDesde = now;
        } else if (now - s.presionBajaDesde >= s.WINDOW_PRESION) {
            const fa = getFuenteActiva();
            const elapsed = Math.round((now - s.presionBajaDesde) / 1000);
            console.log(`⚠️ Presión baja ${elapsed}s — failover desde ${fa}`);
            ejecutarFailover(`presion_baja_${fa}`);
        }
    } else {
        s.presionBajaDesde = null;
    }
}

// ─── Fin del motor de reglas ─────────────────────────────────────────────────

// --- Lógica del Puente (MQTT -> MySQL) ---
client.on('message', async (topic, message) => {
    try {
        // ── Regla 11: Heartbeat ESP32 (string "online", no numérico) ─────────
        if (topic === 'agua_iot/heartbeat/control_calle') {
            const wasOffline = !sistemaEstado.esp32CalleOnline;
            sistemaEstado.lastHeartbeatCalle = Date.now();
            sistemaEstado.esp32CalleOnline   = true;
            if (wasOffline) {
                autoNotificacion('esp32_online', { fuente: 'calle' });
                console.log('✅ ESP32 Calle ONLINE');
            }
            return;
        }
        if (topic === 'agua_iot/heartbeat/control_lluvia') {
            const wasOffline = !sistemaEstado.esp32LluviaOnline;
            sistemaEstado.lastHeartbeatLluvia = Date.now();
            sistemaEstado.esp32LluviaOnline   = true;
            if (wasOffline) {
                autoNotificacion('esp32_online', { fuente: 'lluvia' });
                console.log('✅ ESP32 Lluvia ONLINE');
            }
            return;
        }

        const valor = parseFloat(message.toString());

        if (isNaN(valor)) {
            console.warn(`[WARN] Mensaje en ${topic} no es numérico. Ignorando:`, message.toString());
            return;
        }

        const id_componente = TOPIC_MAP[topic];
        if (id_componente === undefined) {
            console.log(`[WARN] Tópico desconocido omitido: ${topic}`);
            return;
        }

        console.log(`📩 Recibido - Tópico: ${topic} | Valor: ${valor} | ID Componente: ${id_componente}`);

        if (pool) {
            const query = `INSERT INTO lecturas (id_componente, valor, fecha) VALUES (?, ?, NOW())`;
            await pool.execute(query, [id_componente, valor]);
            console.log(`💾 Guardado en MySQL - Componente ID: ${id_componente}, Valor: ${valor}`);
        } else {
            console.warn(`⚠️ DB no está lista. Mensaje de ${topic} ignorado.`);
        }

        // --- Forward to Flutter Web clients ---
        wsClients.forEach(ws => {
            if (ws.readyState === 1) { // WebSocket.OPEN
                ws.send(JSON.stringify({ topic, value: valor }));
            }
        });

        // --- 🧠 Motor de Reglas Inteligentes ---
        // 1. Actualizar el estado interno del motor con el nuevo valor
        syncEstado(topic, valor);
        // 2. Evaluar reglas SOLO si el modo prueba NO está activo
        if (!modoPrueba) {
            evaluarReglasInteligentes(topic);
        } else {
            console.log(`🧪 MODO PRUEBA: reglas omitidas para ${topic}`);
        }

        // --- Evaluación de umbrales y notificaciones ---
        // Publica a agua_iot/notificaciones cuando se detecta un valor crítico.
        // Flutter escucha este tópico para disparar alertas verificadas por el bridge.

        // 🔔 Turbidez crítica — DESACTIVADO: sensor no verificado en hardware actual
        // if (topic === 'agua_iot/calidad/turbidez' && valor > 50) {
        //     const notif = JSON.stringify({ type: 'turbidez_critica', value: valor });
        //     client.publish('agua_iot/notificaciones', notif, { qos: 1 });
        //     console.log(`🔔 Notificación enviada → turbidez_critica: ${valor} NTU`);
        // }

        // 🔔 Presión baja — cubre tanto el simulador (legacy) como el ESP32 real
        if (
            (topic === 'agua_iot/sensores_presion/1' || topic === 'agua_iot/sensores/presion')
            && valor < 10
        ) {
            const notif = JSON.stringify({ type: 'baja_presion', value: valor });
            client.publish('agua_iot/notificaciones', notif, { qos: 1 });
            console.log(`🔔 Notificación enviada → baja_presion: ${valor} PSI`);
        }

        // 🔔 Tanque vacío — se dispara cuando el nivel calculado llega a 0
        if (topic === 'agua_iot/tanque_calle/nivel' && valor === 0) {
            const notif = JSON.stringify({ type: 'tanque_calle_vacio', value: valor });
            client.publish('agua_iot/notificaciones', notif, { qos: 1 });
            console.log(`🔔 Notificación enviada → tanque_calle_vacio`);
        }
        if (topic === 'agua_iot/tanque_lluvia/nivel' && valor === 0) {
            const notif = JSON.stringify({ type: 'tanque_lluvia_vacio', value: valor });
            client.publish('agua_iot/notificaciones', notif, { qos: 1 });
            console.log(`🔔 Notificación enviada → tanque_lluvia_vacio`);
        }

    } catch (error) {
        console.error('❌ Error procesando mensaje MQTT:', error);
    }
});


// --- API HTTP para Lecturas Históricas ---
const API_PORT = process.env.API_PORT || 3001;

const server = http.createServer(async (req, res) => {
    // CORS headers para Flutter Web
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Content-Type', 'application/json');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        return res.end();
    }

    // GET /api/lecturas — Últimas 24 horas
    if (req.url === '/api/lecturas' && req.method === 'GET') {
        try {
            if (!pool) {
                res.writeHead(503);
                return res.end(JSON.stringify({ error: 'DB no disponible' }));
            }

            const [rows] = await pool.execute(`
                SELECT id_componente, valor, fecha
                FROM lecturas
                WHERE fecha >= NOW() - INTERVAL 24 HOUR
                ORDER BY fecha ASC
            `);

            res.writeHead(200);
            res.end(JSON.stringify(rows));
        } catch (err) {
            console.error('❌ Error en API:', err.message);
            res.writeHead(500);
            res.end(JSON.stringify({ error: err.message }));
        }
        return;
    }

    // ── GET /api/consumo/hoy — Consumo del día actual en tiempo real ──────────
    // Calcula litros de lluvia y calle consumidos hoy desde lecturas de nivel.
    // Fórmula: Σ(caídas de nivel > 0.5% y < 15%) × capacidad_tanque / 100
    if (req.url === '/api/consumo/hoy' && req.method === 'GET') {
        try {
            if (!pool) { res.writeHead(503); return res.end(JSON.stringify({ error: 'DB no disponible' })); }

            // Leer niveles de lluvia (id=3) y calle (id=4) de las últimas 24h
            const [rainRows] = await pool.execute(`
                SELECT valor, fecha FROM lecturas
                WHERE id_componente = 3 AND fecha >= NOW() - INTERVAL 24 HOUR
                ORDER BY fecha ASC
            `);
            const [streetRows] = await pool.execute(`
                SELECT valor, fecha FROM lecturas
                WHERE id_componente = 4 AND fecha >= NOW() - INTERVAL 24 HOUR
                ORDER BY fecha ASC
            `);
            const [faultRows] = await pool.execute(`
                SELECT COUNT(*) as total FROM fault_events
                WHERE fecha >= NOW() - INTERVAL 24 HOUR
            `);

            // Función: acumular caídas válidas de nivel
            function calcLitros(rows, capacidad = 200) {
                let litros = 0;
                for (let i = 1; i < rows.length; i++) {
                    const delta = rows[i - 1].valor - rows[i].valor;
                    if (delta >= 0.5 && delta <= 15) {
                        litros += (delta * capacidad) / 100;
                    }
                }
                return Math.round(litros * 10) / 10;
            }

            const litrosLluvia  = calcLitros(rainRows);
            const litrosCalle   = calcLitros(streetRows);
            const total         = litrosLluvia + litrosCalle;
            const eficiencia    = total > 0 ? Math.round((litrosLluvia / total) * 1000) / 10 : 0;

            // Calcular hora pico desde lluvia + calle combinados
            const allLevels = [...rainRows, ...streetRows]
                .sort((a, b) => new Date(a.fecha) - new Date(b.fecha));
            const buckets = {};
            for (let i = 1; i < allLevels.length; i++) {
                const delta = allLevels[i-1].valor - allLevels[i].valor;
                if (delta > 0) {
                    const h = new Date(allLevels[i].fecha).getHours();
                    buckets[h] = (buckets[h] || 0) + delta;
                }
            }
            let peakHour = '--:--';
            if (Object.keys(buckets).length > 0) {
                const peakH = Object.entries(buckets).reduce((a, b) => b[1] > a[1] ? b : a)[0];
                peakHour = String(peakH).padStart(2, '0') + ':00';
            }

            res.writeHead(200);
            res.end(JSON.stringify({
                fecha          : new Date().toISOString().split('T')[0],
                litros_lluvia  : litrosLluvia,
                litros_calle   : litrosCalle,
                total_litros   : total,
                eficiencia_pct : eficiencia,
                hora_pico      : peakHour,
                fallas_hoy     : faultRows[0].total,
                muestras       : rainRows.length + streetRows.length,
                generado_en    : new Date().toISOString(),
            }));
        } catch (err) {
            console.error('❌ Error en /api/consumo/hoy:', err.message);
            res.writeHead(500);
            res.end(JSON.stringify({ error: err.message }));
        }
        return;
    }

    // ── GET /api/consumo/historico?dias=7 — Historial diario de consumo ───────
    // Devuelve resumen de litros por día para los últimos N días (default 7).
    if (req.url.startsWith('/api/consumo/historico') && req.method === 'GET') {
        try {
            if (!pool) { res.writeHead(503); return res.end(JSON.stringify({ error: 'DB no disponible' })); }

            const params  = new URL(req.url, 'http://localhost').searchParams;
            const dias    = Math.min(parseInt(params.get('dias') || '7', 10), 90);
            const cap     = parseInt(params.get('capacidad') || '200', 10);

            // Lecturas de nivel agrupadas por día
            const [rainDays] = await pool.execute(`
                SELECT DATE(fecha) as dia, valor, fecha
                FROM lecturas
                WHERE id_componente = 3
                  AND fecha >= NOW() - INTERVAL ? DAY
                ORDER BY fecha ASC
            `, [dias]);

            const [streetDays] = await pool.execute(`
                SELECT DATE(fecha) as dia, valor, fecha
                FROM lecturas
                WHERE id_componente = 4
                  AND fecha >= NOW() - INTERVAL ? DAY
                ORDER BY fecha ASC
            `, [dias]);

            // Agrupar por día
            function groupByDay(rows) {
                const map = {};
                rows.forEach(r => {
                    const d = r.dia || r.fecha?.toString().split('T')[0];
                    if (!map[d]) map[d] = [];
                    map[d].push(r);
                });
                return map;
            }

            function calcLitrosDia(rows, capacidad) {
                let litros = 0;
                for (let i = 1; i < rows.length; i++) {
                    const delta = rows[i-1].valor - rows[i].valor;
                    if (delta >= 0.5 && delta <= 15) litros += (delta * capacidad) / 100;
                }
                return Math.round(litros * 10) / 10;
            }

            const rainMap   = groupByDay(rainDays);
            const streetMap = groupByDay(streetDays);

            // Construir lista de los últimos N días
            const resultado = [];
            for (let i = dias - 1; i >= 0; i--) {
                const d = new Date();
                d.setDate(d.getDate() - i);
                const dStr = d.toISOString().split('T')[0];
                const lr = calcLitrosDia(rainMap[dStr] || [], cap);
                const lc = calcLitrosDia(streetMap[dStr] || [], cap);
                const tot = lr + lc;
                resultado.push({
                    fecha          : dStr,
                    litros_lluvia  : lr,
                    litros_calle   : lc,
                    total_litros   : tot,
                    eficiencia_pct : tot > 0 ? Math.round((lr / tot) * 1000) / 10 : 0,
                });
            }

            res.writeHead(200);
            res.end(JSON.stringify(resultado));
        } catch (err) {
            console.error('❌ Error en /api/consumo/historico:', err.message);
            res.writeHead(500);
            res.end(JSON.stringify({ error: err.message }));
        }
        return;
    }

    // ── GAP 1: GET /api/thresholds — Umbrales adaptativos desde histórico ────
    // Calcula P10/P90 de lecturas de presión y flujo de los últimos 7 días.
    if (req.url === '/api/thresholds' && req.method === 'GET') {
        try {
            if (!pool) {
                res.writeHead(503);
                return res.end(JSON.stringify({ error: 'DB no disponible' }));
            }
            // Leer lecturas de presión (id=1) y flujo (id=2) de los últimos 7 días
            const [presRows] = await pool.execute(`
                SELECT valor FROM lecturas
                WHERE id_componente = 1
                  AND fecha >= NOW() - INTERVAL 7 DAY
                  AND valor > 0
                ORDER BY valor ASC
            `);
            const [flowRows] = await pool.execute(`
                SELECT valor FROM lecturas
                WHERE id_componente = 2
                  AND fecha >= NOW() - INTERVAL 7 DAY
                  AND valor > 0.1
                ORDER BY valor ASC
            `);

            function percentile(sorted, p) {
                if (sorted.length === 0) return null;
                const idx = Math.floor(sorted.length * p);
                return sorted[Math.min(idx, sorted.length - 1)].valor;
            }

            const presP10  = percentile(presRows, 0.10);
            const presP90  = percentile(presRows, 0.90);
            const flowP10  = percentile(flowRows, 0.10);
            const flowP90  = percentile(flowRows, 0.90);

            const thresholds = {
                pressure: {
                    p10          : presP10,
                    p90          : presP90,
                    adaptiveMin  : presP10 !== null ? Math.max(presP10 * 0.7, 5)  : 10,
                    adaptiveMax  : presP90 !== null ? Math.min(presP90 * 1.3, 55) : 45,
                    sampleCount  : presRows.length,
                },
                flow: {
                    p10         : flowP10,
                    p90         : flowP90,
                    adaptiveMin : flowP10 !== null ? Math.max(flowP10 * 0.5, 0.1) : 0.5,
                    sampleCount : flowRows.length,
                },
                generatedAt : new Date().toISOString(),
                windowDays  : 7,
            };

            res.writeHead(200);
            res.end(JSON.stringify(thresholds));
        } catch (err) {
            console.error('❌ Error en /api/thresholds:', err.message);
            res.writeHead(500);
            res.end(JSON.stringify({ error: err.message }));
        }
        return;
    }

    // ── GAP 2: GET /api/fault-history — Historial de fallas recientes ────────
    if (req.url.startsWith('/api/fault-history') && req.method === 'GET') {
        try {
            if (!pool) {
                res.writeHead(503);
                return res.end(JSON.stringify({ error: 'DB no disponible' }));
            }
            const [rows] = await pool.execute(`
                SELECT fault_type, fuente_activa, presion, flujo, detalles, fecha
                FROM fault_events
                WHERE fecha >= NOW() - INTERVAL 7 DAY
                ORDER BY fecha DESC
                LIMIT 100
            `);
            res.writeHead(200);
            res.end(JSON.stringify(rows));
        } catch (err) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: err.message }));
        }
        return;
    }

    // GET /api/health — Health check
    if (req.url === '/api/health' && req.method === 'GET') {
        res.writeHead(200);
        res.end(JSON.stringify({
            status: 'ok',
            mqtt: client.connected ? 'connected' : 'disconnected',
            db: pool ? 'ready' : 'not_ready',
            uptime: process.uptime(),
            testMode: modoPrueba
        }));
        return;
    }

    // GET /api/test-mode — Leer estado actual del modo prueba
    if (req.url === '/api/test-mode' && req.method === 'GET') {
        res.writeHead(200);
        res.end(JSON.stringify({ testMode: modoPrueba }));
        return;
    }

    // POST /api/test-mode — Activar o desactivar modo prueba
    if (req.url === '/api/test-mode' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const { active } = JSON.parse(body);
                modoPrueba = Boolean(active);
                console.log(`🧪 Modo Prueba ${modoPrueba ? 'ACTIVADO ⚠️' : 'DESACTIVADO ✅'} via HTTP`);
                res.writeHead(200);
                res.end(JSON.stringify({ testMode: modoPrueba }));
            } catch (e) {
                res.writeHead(400);
                res.end(JSON.stringify({ error: 'Body inválido. Enviar: {"active": true|false}' }));
            }
        });
        return;
    }

    // ── POST /api/test-email — enviar email de prueba ──────────────────────────
    if (req.method === 'POST' && req.url === '/api/test-email') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', async () => {
            // Verificar credenciales antes de intentar
            if (!process.env.EMAIL_APP_PASS ||
                process.env.EMAIL_APP_PASS === 'REEMPLAZA_CON_TU_APP_PASSWORD' ||
                !process.env.EMAIL_USER || !process.env.EMAIL_TO) {
                res.writeHead(200);
                return res.end(JSON.stringify({
                    ok: false,
                    error: 'EMAIL_APP_PASS, EMAIL_USER o EMAIL_TO no configurados. Revisa las variables de entorno en Render.'
                }));
            }
            try {
                // Envio directo al transporter (sin cooldown)
                await emailTransporter.sendMail({
                    from: `"SIGA Alerts" <${process.env.EMAIL_USER}>`,
                    to: process.env.EMAIL_TO,
                    subject: '🧪 SIGA — Email de Prueba',
                    html: `<div style="font-family:sans-serif;background:#0d1117;color:#e6edf3;padding:32px;border-radius:12px">
                      <div style="border-left:4px solid #00e5ff;padding-left:16px;margin-bottom:24px">
                        <h2 style="color:#00e5ff;margin:0">SIGA</h2>
                        <p style="color:#8b949e;margin:4px 0">Sistema Inteligente de Gestion de Agua</p>
                      </div>
                      <h3 style="color:#00e5ff">Correo de Prueba</h3>
                      <p>Las alertas por email estan funcionando correctamente.</p>
                      <p style="color:#8b949e">Destino: <b>${process.env.EMAIL_TO}</b></p>
                      <p style="color:#8b949e;font-size:12px">Enviado el ${new Date().toLocaleString('es-VE',{timeZone:'America/Caracas'})} (VET)</p>
                    </div>`,
                });
                console.log(`[Email] Prueba enviada a ${process.env.EMAIL_TO}`);
                res.writeHead(200);
                res.end(JSON.stringify({ ok: true, message: process.env.EMAIL_TO }));
            } catch (e) {
                console.error(`[Email] Error test-email: ${e.message}`);
                res.writeHead(200);
                res.end(JSON.stringify({ ok: false, error: e.message }));
            }
        });
        return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 🔑 AUTH ENDPOINTS
    // ═══════════════════════════════════════════════════════════════════════

    // POST /api/auth/login
    if (req.method === 'POST' && req.url === '/api/auth/login') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', async () => {
            try {
                if (!pool) { res.writeHead(503); res.end(JSON.stringify({ error: 'DB no disponible' })); return; }
                const { email, password } = JSON.parse(body);
                if (!email || !password) {
                    res.writeHead(400); res.end(JSON.stringify({ error: 'Email y contraseña requeridos' })); return;
                }
                const [rows] = await pool.execute(
                    'SELECT id, nombre, email, password_hash, rol_global FROM usuarios WHERE email = ? AND activo = TRUE',
                    [email.trim().toLowerCase()]
                );
                if (rows.length === 0) { res.writeHead(401); res.end(JSON.stringify({ error: 'Credenciales inválidas' })); return; }
                const user = rows[0];
                const match = await bcrypt.compare(password, user.password_hash);
                if (!match) { res.writeHead(401); res.end(JSON.stringify({ error: 'Credenciales inválidas' })); return; }
                const token = signToken({ id: user.id, email: user.email, rol: user.rol_global });
                console.log(`🔑 Login: ${user.email} (${user.rol_global})`);
                res.writeHead(200);
                res.end(JSON.stringify({ token, user: { id: user.id, nombre: user.nombre, email: user.email, rol: user.rol_global } }));
            } catch (e) {
                console.error('Login error:', e.message);
                res.writeHead(500); res.end(JSON.stringify({ error: 'Error interno' }));
            }
        });
        return;
    }

    // GET /api/auth/me
    if (req.method === 'GET' && req.url === '/api/auth/me') {
        const token = extractToken(req);
        if (!token) { res.writeHead(401); res.end(JSON.stringify({ error: 'No autenticado' })); return; }
        const payload = verifyToken(token);
        if (!payload) { res.writeHead(401); res.end(JSON.stringify({ error: 'Token inválido' })); return; }
        try {
            if (!pool) { res.writeHead(503); res.end(JSON.stringify({ error: 'DB no disponible' })); return; }
            const [rows] = await pool.execute(
                'SELECT id, nombre, email, rol_global FROM usuarios WHERE id = ? AND activo = TRUE', [payload.id]
            );
            if (rows.length === 0) { res.writeHead(401); res.end(JSON.stringify({ error: 'Usuario no encontrado' })); return; }
            res.writeHead(200);
            res.end(JSON.stringify({ user: { ...rows[0], rol: rows[0].rol_global } }));
        } catch (e) { res.writeHead(500); res.end(JSON.stringify({ error: 'Error interno' })); }
        return;
    }

    // POST /api/auth/logout
    if (req.method === 'POST' && req.url === '/api/auth/logout') {
        const token = extractToken(req);
        if (token) { const p = verifyToken(token); if (p) console.log(`🚪 Logout: ${p.email}`); }
        res.writeHead(200); res.end(JSON.stringify({ ok: true }));
        return;
    }

    // POST /api/usuarios  — crear usuario (solo admin)
    if (req.method === 'POST' && req.url === '/api/usuarios') {
        const token = extractToken(req);
        if (!token) { res.writeHead(401); res.end(JSON.stringify({ error: 'No autenticado' })); return; }
        const payload = verifyToken(token);
        if (!payload || payload.rol !== 'admin') { res.writeHead(403); res.end(JSON.stringify({ error: 'Solo administradores' })); return; }
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', async () => {
            try {
                if (!pool) { res.writeHead(503); res.end(JSON.stringify({ error: 'DB no disponible' })); return; }
                const { nombre, email, password, rol } = JSON.parse(body);
                if (!nombre || !email || !password) { res.writeHead(400); res.end(JSON.stringify({ error: 'nombre, email y password requeridos' })); return; }
                const rolFinal = ['admin','operador','viewer'].includes(rol) ? rol : 'operador';
                const hash = await bcrypt.hash(password, 12);
                const [result] = await pool.execute(
                    'INSERT INTO usuarios (nombre, email, password_hash, rol_global) VALUES (?, ?, ?, ?)',
                    [nombre, email.trim().toLowerCase(), hash, rolFinal]
                );
                await pool.execute(
                    'INSERT IGNORE INTO usuario_sistema (usuario_id, sistema_id, rol) VALUES (?, 1, ?)',
                    [result.insertId, rolFinal]
                );
                console.log(`👤 Nuevo usuario: ${email} (${rolFinal}) por ${payload.email}`);
                res.writeHead(201);
                res.end(JSON.stringify({ ok: true, user: { id: result.insertId, nombre, email: email.trim().toLowerCase(), rol: rolFinal } }));
            } catch (e) {
                if (e.code === 'ER_DUP_ENTRY') { res.writeHead(409); res.end(JSON.stringify({ error: 'El email ya está registrado' })); }
                else { res.writeHead(500); res.end(JSON.stringify({ error: 'Error interno' })); }
            }
        });
        return;
    }

    // GET /api/usuarios  — listar usuarios (solo admin)
    if (req.method === 'GET' && req.url === '/api/usuarios') {
        const token = extractToken(req);
        if (!token) { res.writeHead(401); res.end(JSON.stringify({ error: 'No autenticado' })); return; }
        const payload = verifyToken(token);
        if (!payload || payload.rol !== 'admin') { res.writeHead(403); res.end(JSON.stringify({ error: 'Solo administradores' })); return; }
        try {
            if (!pool) { res.writeHead(503); res.end(JSON.stringify({ error: 'DB no disponible' })); return; }
            const [rows] = await pool.execute(
                `SELECT u.id, u.nombre, u.email, u.rol_global as rol, u.activo, u.creado_en
                 FROM usuarios u JOIN usuario_sistema us ON us.usuario_id = u.id AND us.sistema_id = 1
                 ORDER BY u.creado_en ASC`
            );
            res.writeHead(200); res.end(JSON.stringify({ usuarios: rows }));
        } catch (e) { res.writeHead(500); res.end(JSON.stringify({ error: 'Error interno' })); }
        return;
    }

    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(API_PORT, () => {
    console.log(`📊 API HTTP disponible en http://localhost:${API_PORT}/api/lecturas`);
    console.log(`❤️ Health check en http://localhost:${API_PORT}/api/health`);
    console.log(`🔌 WebSocket local en ws://localhost:${API_PORT}`);
});

// --- WebSocket Server (Flutter Web bridge) ---
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
    wsClients.add(ws);
    console.log(`🔌 Flutter Web conectado via WS (${wsClients.size} cliente(s))`);

    // Send connection confirmation
    ws.send(JSON.stringify({ type: 'connected', message: 'Bridge WS OK' }));

    // ── Enviar snapshot del estado actual al nuevo cliente ────────────────────
    // Problema raíz: los mensajes MQTT retenidos llegan al bridge ANTES de que
    // Flutter abra el WebSocket → el estado actual nunca llega a la app.
    // Solución: al conectar, reenviar todo el estado conocido inmediatamente.
    const snapshot = [
        { topic: 'agua_iot/actuadores/bomba',             value: sistemaEstado.bombaPrincipal ? 1 : 0 },
        { topic: 'agua_iot/actuadores/bomba_calle',       value: sistemaEstado.bombaCalle     ? 1 : 0 },
        { topic: 'agua_iot/actuadores/solenoide_calle',   value: sistemaEstado.solenoideCalle ? 1 : 0 },
        { topic: 'agua_iot/actuadores/bomba_lluvia',      value: sistemaEstado.bombaLluvia    ? 1 : 0 },
        { topic: 'agua_iot/actuadores/solenoide_lluvia',  value: sistemaEstado.soleLluvia     ? 1 : 0 },
        { topic: 'agua_iot/sensores_presion/1',           value: sistemaEstado.presion },
        { topic: 'agua_iot/sensores_presion/2',           value: sistemaEstado.flujo },
        { topic: 'agua_iot/tanque_calle/nivel',           value: sistemaEstado.tankCalle },
        { topic: 'agua_iot/tanque_lluvia/nivel',          value: sistemaEstado.tankLluvia },
    ];
    snapshot.forEach(item => {
        if (ws.readyState === 1) ws.send(JSON.stringify(item));
    });
    console.log(`📦 Snapshot enviado a nuevo cliente WS — bomba_calle=${sistemaEstado.bombaCalle}, sol_calle=${sistemaEstado.solenoideCalle}, bomba_lluvia=${sistemaEstado.bombaLluvia}, sol_lluvia=${sistemaEstado.soleLluvia}`);

    // Handle actuator commands from Flutter Web
    // Format: { "command": "bomba_calle" | "solenoide_calle" | etc, "value": "1"|"0" }
    ws.on('message', (data) => {
        try {
            const msg = JSON.parse(data.toString());
            if (msg.command && msg.value !== undefined) {
                const topicMap = {
                    // ESP32_Bomba_Unica (standalone)
                    'bomba'            : 'agua_iot/actuadores/bomba',
                    'solenoide'        : 'agua_iot/actuadores/solenoide',
                    // ESP32_WaterSmart_Alan — Fuente 1 (calle)
                    'bomba_calle'      : 'agua_iot/actuadores/bomba_calle',
                    'solenoide_calle'  : 'agua_iot/actuadores/solenoide_calle',
                    // ESP32_WaterSmart_Alan — Fuente 2 (lluvia)
                    'bomba_lluvia'     : 'agua_iot/actuadores/bomba_lluvia',
                    'solenoide_lluvia' : 'agua_iot/actuadores/solenoide_lluvia',
                };
                const topic = topicMap[msg.command];
                if (topic) {
                    // ── REGLA: Las fuentes no pueden activarse sin la Bomba Principal ──────
                    const esFuente = ['bomba_calle', 'solenoide_calle', 'bomba_lluvia', 'solenoide_lluvia'].includes(msg.command);
                    const intentandoEncender = String(msg.value) === '1';

                    if (esFuente && intentandoEncender && !sistemaEstado.bombaPrincipal) {
                        console.warn(`🔒 INTERLOCK: Intento de encender ${msg.command} sin Bomba Principal activa — BLOQUEADO`);
                        // Notificar a Flutter del bloqueo
                        if (ws.readyState === 1) {
                            ws.send(JSON.stringify({
                                type: 'interlock_block',
                                reason: 'bomba_principal_off',
                                command: msg.command,
                                message: 'La Bomba Principal debe estar encendida antes de activar una fuente'
                            }));
                        }
                        return; // No publicar el comando
                    }

                    console.log(`🔧 Comando desde Flutter Web: ${topic} = ${msg.value}`);
                    client.publish(topic, String(msg.value), { qos: 1, retain: true });
                } else {
                    console.warn(`⚠️ Comando desconocido: ${msg.command}`);
                }
            }
        } catch (e) {
            console.error('⚠️ Error parseando mensaje WS:', e.message);
        }
    });

    ws.on('close', () => {
        wsClients.delete(ws);
        console.log(`\uD83D\uDD0C Flutter Web desconectado (${wsClients.size} cliente(s))`);
    });

    ws.on('error', (err) => {
        console.error('\u26A0\uFE0F WS error:', err.message);
        wsClients.delete(ws);
    });
});




// Manejo de cierres limpios
process.on('SIGINT', async () => {
    console.log('\n🛑 Cerrando aplicación...');
    client.end();
    server.close();
    if (pool) {
        await pool.end();
    }
    process.exit(0);
});

// ═══════════════════════════════════════════════════════════════════════════════
// 🔍 WATCHDOG — Regla 11: Detector de ESP32 Offline
// Corre cada 15s y comprueba si algún ESP32 dejó de enviar heartbeat.
// Si el ESP32 de control cae, notifica a Flutter para alertar al usuario.
// ═══════════════════════════════════════════════════════════════════════════════
setInterval(() => {
    const ahora = Date.now();
    const timeout = sistemaEstado.HEARTBEAT_TIMEOUT_MS;

    // ── ESP32 Calle ───────────────────────────────────────────────────────────
    if (sistemaEstado.esp32CalleOnline && sistemaEstado.lastHeartbeatCalle) {
        const silencio = ahora - sistemaEstado.lastHeartbeatCalle;
        if (silencio > timeout) {
            sistemaEstado.esp32CalleOnline = false;
            console.warn(`⚠️ ESP32 Calle OFFLINE — sin heartbeat por ${Math.round(silencio/1000)}s`);
            autoNotificacion('esp32_offline', {
                fuente: 'calle',
                silencioSegundos: Math.round(silencio / 1000)
            });
        }
    }

    // ── ESP32 Lluvia ──────────────────────────────────────────────────────────
    if (sistemaEstado.esp32LluviaOnline && sistemaEstado.lastHeartbeatLluvia) {
        const silencio = ahora - sistemaEstado.lastHeartbeatLluvia;
        if (silencio > timeout) {
            sistemaEstado.esp32LluviaOnline = false;
            console.warn(`⚠️ ESP32 Lluvia OFFLINE — sin heartbeat por ${Math.round(silencio/1000)}s`);
            autoNotificacion('esp32_offline', {
                fuente: 'lluvia',
                silencioSegundos: Math.round(silencio / 1000)
            });
        }
    }
}, 15000); // Revisar cada 15 segundos
