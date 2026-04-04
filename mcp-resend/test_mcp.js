#!/usr/bin/env node

/**
 * Script de prueba para el servidor MCP de Resend
 * Ejecuta este script para verificar que la configuración funciona correctamente
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log('🧪 Probando servidor MCP de Resend...\n');

// Verificar que el archivo build existe
const buildPath = join(__dirname, 'build', 'index.js');
console.log(`📁 Verificando archivo: ${buildPath}`);

try {
  const fs = await import('fs');
  if (!fs.existsSync(buildPath)) {
    console.error('❌ Error: El archivo build/index.js no existe');
    console.log('💡 Ejecuta: npm run build');
    process.exit(1);
  }
  console.log('✅ Archivo build/index.js encontrado');
} catch (error) {
  console.error('❌ Error verificando archivo:', error.message);
  process.exit(1);
}

// Verificar variables de entorno
console.log('\n🔑 Verificando variables de entorno...');
const requiredEnvVars = ['RESEND_API_KEY'];
const missingVars = [];

for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    missingVars.push(envVar);
  } else {
    console.log(`✅ ${envVar}: ${process.env[envVar].substring(0, 10)}...`);
  }
}

if (missingVars.length > 0) {
  console.log('\n❌ Variables de entorno faltantes:');
  missingVars.forEach(varName => {
    console.log(`   - ${varName}`);
  });
  console.log('\n💡 Configura las variables de entorno en tu archivo mcp.json');
  process.exit(1);
}

// Probar el servidor MCP
console.log('\n🚀 Iniciando servidor MCP...');
const mcpProcess = spawn('node', [buildPath], {
  stdio: ['pipe', 'pipe', 'pipe'],
  env: process.env
});

let output = '';
let errorOutput = '';

mcpProcess.stdout.on('data', (data) => {
  output += data.toString();
});

mcpProcess.stderr.on('data', (data) => {
  errorOutput += data.toString();
});

mcpProcess.on('close', (code) => {
  console.log(`\n📊 Código de salida: ${code}`);
  
  if (code === 0) {
    console.log('✅ Servidor MCP iniciado correctamente');
    if (output) {
      console.log('\n📤 Salida del servidor:');
      console.log(output);
    }
  } else {
    console.log('❌ Error iniciando servidor MCP');
    if (errorOutput) {
      console.log('\n📤 Error del servidor:');
      console.log(errorOutput);
    }
  }
});

// Enviar comando de prueba después de 2 segundos
setTimeout(() => {
  console.log('\n📨 Enviando comando de prueba...');
  
  // Comando MCP para listar herramientas disponibles
  const testCommand = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/list',
    params: {}
  };
  
  mcpProcess.stdin.write(JSON.stringify(testCommand) + '\n');
  
  // Cerrar después de 5 segundos
  setTimeout(() => {
    mcpProcess.kill();
    console.log('\n🏁 Prueba completada');
  }, 5000);
}, 2000);

// Manejar errores
mcpProcess.on('error', (error) => {
  console.error('❌ Error ejecutando servidor MCP:', error.message);
  process.exit(1);
});
