const mqtt = require('mqtt');
require('dotenv').config();

// --- Configuración e Inicialización de MQTT ---
const mqttUrl = `mqtts://${process.env.MQTT_HOST}:${process.env.MQTT_PORT}`;
const mqttOptions = {
  clientId: 'iot_simulador_' + Math.random().toString(16).slice(2, 8),
  username: process.env.MQTT_USER,
  password: process.env.MQTT_PASS,
  reconnectPeriod: 5000,
  rejectUnauthorized: true
};

console.log(`[Simulador] Conectando a MQTT: ${mqttUrl}...`);
const client = mqtt.connect(mqttUrl, mqttOptions);

// Estado acumulativo para simulación realista
let rainTankLevel = 65.0;
let streetTankLevel = 80.0;
let isPumpActive = false;
let isSolenoidOpen = true;

client.on('connect', () => {
  console.log('✅ Simulador conectado a HiveMQ Cloud con éxito');
  
  // Enviar valores cada 5 segundos
  setInterval(() => {
    try {
      // --- Sensores de Presión (30-45 PSI con fluctuación) ---
      const presion1 = (Math.random() * (45 - 30) + 30).toFixed(2);
      const presion2 = (Math.random() * (45 - 30) + 30).toFixed(2);
      
      // --- Niveles de Tanque (fluctuación gradual ±2%) ---
      rainTankLevel = Math.max(0, Math.min(100,
        rainTankLevel + (Math.random() * 4 - 2)
      ));
      streetTankLevel = Math.max(0, Math.min(100,
        streetTankLevel + (Math.random() * 4 - 2)
      ));

      // --- Turbidez (0-8 NTU normal, spike ocasional a 55+) ---
      const turbiditySpikeChance = Math.random();
      const turbidez = turbiditySpikeChance > 0.95
        ? (Math.random() * 20 + 55).toFixed(2)  // Spike de alerta
        : (Math.random() * 8).toFixed(2);        // Normal

      // --- Estado Bomba (toggle cada ~30s promedio) ---
      if (Math.random() > 0.85) isPumpActive = !isPumpActive;

      // Publicar todos los sensores
      client.publish('agua_iot/sensores_presion/1', presion1.toString());
      console.log(`📤 sensores_presion/1 → ${presion1} PSI`);

      client.publish('agua_iot/sensores_presion/2', presion2.toString());
      console.log(`📤 sensores_presion/2 → ${presion2} PSI`);

      client.publish('agua_iot/nivel/lectura', rainTankLevel.toFixed(2));
      console.log(`📤 nivel/lectura → ${rainTankLevel.toFixed(2)} %`);

      client.publish('agua_iot/nivel/lectura_2', streetTankLevel.toFixed(2));
      console.log(`📤 nivel/lectura_2 → ${streetTankLevel.toFixed(2)} %`);

      client.publish('agua_iot/calidad/turbidez', turbidez.toString());
      console.log(`📤 calidad/turbidez → ${turbidez} NTU`);

      client.publish('agua_iot/actuadores/bomba', isPumpActive ? '1' : '0');
      console.log(`📤 actuadores/bomba → ${isPumpActive ? 'ON' : 'OFF'}`);

      // Estado solenoide (toggle cada ~20% chance)
      if (Math.random() > 0.8) isSolenoidOpen = !isSolenoidOpen;
      client.publish('agua_iot/actuadores/solenoide', isSolenoidOpen ? '1' : '0');
      console.log(`📤 actuadores/solenoide → ${isSolenoidOpen ? 'OPEN' : 'CLOSED'}`);

      console.log('---');
      
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
