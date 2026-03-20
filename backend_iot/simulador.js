const mqtt = require('mqtt');
require('dotenv').config();

// --- Configuración e Inicialización de MQTT ---
const mqttUrl = `mqtts://${process.env.MQTT_HOST}:${process.env.MQTT_PORT}`;
const mqttOptions = {
  clientId: 'iot_simulador_' + Math.random().toString(16).slice(2, 8),
  username: process.env.MQTT_USER,
  password: process.env.MQTT_PASS,
  reconnectPeriod: 5000, // Reconexión automática
  rejectUnauthorized: true
};

console.log(`[Simulador] Conectando a MQTT: ${mqttUrl}...`);
const client = mqtt.connect(mqttUrl, mqttOptions);

client.on('connect', () => {
  console.log('✅ Simulador conectado a HiveMQ Cloud con éxito');
  
  // Enviar valores cada 5 segundos
  setInterval(() => {
    try {
      // Valores aleatorios realistas
      // Presión: 30-45 PSI
      const presion1 = (Math.random() * (45 - 30) + 30).toFixed(2);
      const presion2 = (Math.random() * (45 - 30) + 30).toFixed(2);
      
      // Nivel: 0-100 %
      const nivel = (Math.random() * 100).toFixed(2);

      // Publicar de forma aislada para simular diferentes sensores
      client.publish('agua_iot/sensores_presion/1', presion1.toString());
      console.log(`📤 Publicado: agua_iot/sensores_presion/1 -> ${presion1} PSI`);

      client.publish('agua_iot/sensores_presion/2', presion2.toString());
      console.log(`📤 Publicado: agua_iot/sensores_presion/2 -> ${presion2} PSI`);

      client.publish('agua_iot/nivel/lectura', nivel.toString());
      console.log(`📤 Publicado: agua_iot/nivel/lectura -> ${nivel} %`);
      
    } catch (error) {
      console.error('❌ Error enviando datos:', error);
    }
  }, 5000);
});

client.on('error', (error) => {
  console.error('❌ Error en MQTT del Simulador:', error);
});

client.on('offline', () => {
  console.log('⚠️ Simulador Offline. Intentando reconectar a MQTT...');
});
