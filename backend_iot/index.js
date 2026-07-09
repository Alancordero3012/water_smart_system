require('dotenv').config();
const mqtt = require('mqtt');
const mysql = require('mysql2/promise');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

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

    const topics = [
        // ── Tópicos Legacy (simulador.js) ────────────────────────────────────
        'agua_iot/sensores_presion/1',
        'agua_iot/sensores_presion/2',
        'agua_iot/nivel/lectura',
        'agua_iot/nivel/lectura_2',
        'agua_iot/calidad/turbidez',
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
        // ── Tópicos ESP32 Presión y Flujo (hardware real) ──────────────────────
        'agua_iot/sensores/presion',
        'agua_iot/sensores/flujo',
        // ── Tópicos ESP32 Actuadores (hardware real) ─────────────────────────
        // ESP32_WaterSmart_Alan: Fuente 1 (calle) y Fuente 2 (lluvia)
        'agua_iot/actuadores/bomba_calle',
        'agua_iot/actuadores/solenoide_calle',
        'agua_iot/actuadores/bomba_lluvia',
        'agua_iot/actuadores/solenoide_lluvia',
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
    'agua_iot/calidad/turbidez':   5,  // Turbidez
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

// --- Lógica del Puente (MQTT -> MySQL) ---
client.on('message', async (topic, message) => {
    try {
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

        // --- Evaluación de umbrales y notificaciones ---
        // Publica a agua_iot/notificaciones cuando se detecta un valor crítico.
        // Flutter escucha este tópico para disparar alertas verificadas por el bridge.

        // 🔔 Turbidez crítica
        if (topic === 'agua_iot/calidad/turbidez' && valor > 50) {
            const notif = JSON.stringify({ type: 'turbidez_critica', value: valor });
            client.publish('agua_iot/notificaciones', notif, { qos: 1 });
            console.log(`🔔 Notificación enviada → turbidez_critica: ${valor} NTU`);
        }

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
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
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

    // GET /api/health — Health check
    if (req.url === '/api/health' && req.method === 'GET') {
        res.writeHead(200);
        res.end(JSON.stringify({
            status: 'ok',
            mqtt: client.connected ? 'connected' : 'disconnected',
            db: pool ? 'ready' : 'not_ready',
            uptime: process.uptime()
        }));
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
    console.log(`\uD83D\uDD0C Flutter Web conectado via WS (${wsClients.size} cliente(s))`);

    // Send connection confirmation
    ws.send(JSON.stringify({ type: 'connected', message: 'Bridge WS OK' }));

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
