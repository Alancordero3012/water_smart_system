require('dotenv').config();
const mqtt = require('mqtt');
const mysql = require('mysql2/promise');
const http = require('http');
const fs = require('fs');
const path = require('path');

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
        'agua_iot/sensores_presion/1',
        'agua_iot/sensores_presion/2',
        'agua_iot/nivel/lectura',
        'agua_iot/nivel/lectura_2',
        'agua_iot/calidad/turbidez',
        'agua_iot/actuadores/bomba',
        'agua_iot/actuadores/solenoide'
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
    'agua_iot/sensores_presion/1': 1,  // Presión Bomba 1
    'agua_iot/sensores_presion/2': 2,  // Presión Bomba 2
    'agua_iot/nivel/lectura':      3,  // Nivel Tanque Lluvia
    'agua_iot/nivel/lectura_2':    4,  // Nivel Tanque Calle
    'agua_iot/calidad/turbidez':   5,  // Turbidez
    'agua_iot/actuadores/bomba':   6,  // Estado Bomba (0/1)
    'agua_iot/actuadores/solenoide': 7, // Estado Solenoide (0/1)
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
