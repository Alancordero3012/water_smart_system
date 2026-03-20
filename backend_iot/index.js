require('dotenv').config();
const mqtt = require('mqtt');
const mysql = require('mysql2/promise');
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
    // SSL requerido para Aiven
    ssl: {
        ca: fs.readFileSync(path.join(__dirname, 'ca.pem'))
    }
};

let pool;

async function initDB() {
    try {
        console.log('⏳ Inicializando pool de conexiones a MySQL...');
        pool = mysql.createPool(dbConfig);
        // Comprobar la conexión
        const connection = await pool.getConnection();
        console.log('✅ Conectado exitosamente a Aiven MySQL vía Pool');
        connection.release();
    } catch (error) {
        console.error('❌ Error inicializando DB:', error.message);
        if (error.code === 'ENOENT') {
            console.error('⚠️ ATENCIÓN: No se encontró el archivo ca.pem necesario para la conexión SSL a Aiven.');
            console.error('Por favor, descarga el certificado ca.pem de tu consola de Aiven y colócalo en:', __dirname);
        }
        // Reintentar conexión en 5 segundos
        console.log('⏳ Reintentando conexión a DB en 5 segundos...');
        setTimeout(initDB, 5000);
    }
}

// Iniciar DB
initDB();


// --- Configuración e Inicialización de MQTT (HiveMQ Cloud) ---
const mqttUrl = `mqtts://${process.env.MQTT_HOST}:${process.env.MQTT_PORT}`;
const mqttOptions = {
    clientId: 'iot_bridge_' + Math.random().toString(16).slice(2, 8),
    username: process.env.MQTT_USER,
    password: process.env.MQTT_PASS,
    reconnectPeriod: 5000, // Reconexión automática
    rejectUnauthorized: true
};

console.log(`⏳ Intentando conectar a MQTT: ${mqttUrl}...`);
const client = mqtt.connect(mqttUrl, mqttOptions);

client.on('connect', () => {
    console.log('✅ Conectado a HiveMQ Cloud con éxito');

    const topics = [
        'agua_iot/sensores_presion/1',
        'agua_iot/sensores_presion/2',
        'agua_iot/nivel/lectura'
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


// --- Lógica del Puente (MQTT -> MySQL) ---
client.on('message', async (topic, message) => {
    try {
        const valor = parseFloat(message.toString());

        // Validación de dato
        if (isNaN(valor)) {
            console.warn(`[WARN] Mensaje en ${topic} no es numérico. Ignorando:`, message.toString());
            return;
        }

        let id_componente;

        // Lógica de mapeo de tópicos a componentes
        switch (topic) {
            case 'agua_iot/sensores_presion/1':
                id_componente = 1;
                break;
            case 'agua_iot/sensores_presion/2':
                id_componente = 2;
                break;
            case 'agua_iot/nivel/lectura':
                id_componente = 3;
                break;
            default:
                console.log(`[WARN] Tópico desconocido omitido: ${topic}`);
                return;
        }

        console.log(`📩 Recibido - Tópico: ${topic} | Valor: ${valor} | Mapeado a ID Componente: ${id_componente}`);

        // Insertar en Base de Datos
        if (pool) {
            const query = `INSERT INTO lecturas (id_componente, valor, fecha) VALUES (?, ?, NOW())`;
            // Usamos el pool para la query, el cual manejará y liberará la conexión automáticamente
            await pool.execute(query, [id_componente, valor]);
            console.log(`💾 Guardado en MySQL - Componente ID: ${id_componente}, Valor: ${valor}`);
        } else {
            console.warn(`⚠️ DB no está lista o conectada aún. Mensaje de ${topic} ignorado.`);
        }

    } catch (error) {
        console.error('❌ Error procesando el mensaje MQTT o guardando en MySQL:', error);
    }
});

// Manejo de cierres limpios
process.on('SIGINT', async () => {
    console.log('\n🛑 Cerrando aplicación...');
    client.end();
    if (pool) {
        await pool.end();
    }
    process.exit(0);
});
