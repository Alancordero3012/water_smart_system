import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Manages the lifecycle of the Node.js backend processes
/// (index.js bridge and simulador.js simulator).
///
/// Only active on desktop platforms (Windows / macOS / Linux).
/// On mobile or web this class is a safe no-op.
class BackendProcessManager {
  Process? _bridgeProcess;
  Process? _simuladorProcess;

  static BackendProcessManager? _instance;
  BackendProcessManager._();

  /// Singleton – one manager for the whole app lifecycle.
  static BackendProcessManager get instance {
    _instance ??= BackendProcessManager._();
    return _instance!;
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Resolves absolute path to `backend_iot/` relative to the project root.
  /// Tries CWD first (works for `flutter run`), then walks up from the exe.
  static String _backendDir() {
    final cwd = Directory.current.path;
    debugPrint('📂 BackendProcessManager: CWD = $cwd');

    final candidate = p.join(cwd, 'backend_iot');
    debugPrint('📂 BackendProcessManager: Buscando → $candidate');
    if (Directory(candidate).existsSync()) return candidate;

    // Fallback: climb from executable location
    final exe = File(Platform.resolvedExecutable).parent.parent.parent.path;
    final fallback = p.join(exe, 'backend_iot');
    debugPrint('📂 BackendProcessManager: Fallback   → $fallback');
    if (Directory(fallback).existsSync()) return fallback;

    throw StateError(
        '❌ No se encontró el directorio backend_iot.\n'
        '   CWD: $cwd\n'
        '   EXE: ${Platform.resolvedExecutable}\n'
        '   Asegúrate de abrir VS Code desde el root del proyecto.');
  }

  /// Validates that `backend_iot/.env` exists.
  /// Warns in the console if only `.env.template` is present.
  static void _checkEnvFile(String backendDir) {
    final envFile = File(p.join(backendDir, '.env'));
    final templateFile = File(p.join(backendDir, '.env.template'));

    if (!envFile.existsSync()) {
      if (templateFile.existsSync()) {
        debugPrint('⚠️  FALTA backend_iot/.env  ──────────────────────────────');
        debugPrint('   El simulador/bridge usará variables de entorno del sistema.');
        debugPrint('   Para configurar credenciales, copia .env.template → .env');
        debugPrint('   y completa los valores reales de HiveMQ y Aiven.');
        debugPrint('────────────────────────────────────────────────────────────');
      } else {
        debugPrint('⚠️  backend_iot/.env no encontrado. Node.js puede fallar al conectar.');
      }
    } else {
      debugPrint('✅ backend_iot/.env encontrado.');
    }
  }

  /// Resolves the `node` executable path.
  ///
  /// On Windows, `Process.start('node', ...)` can fail if Node is installed
  /// via nvm or similar and not in the SYSTEM PATH (only in the user PATH).
  /// We probe common install locations as a fallback.
  static Future<String> _resolveNodeExecutable() async {
    // 1. Try bare "node" – works if node is in PATH
    try {
      final result = await Process.run('node', ['--version']);
      if (result.exitCode == 0) {
        debugPrint('✅ node encontrado en PATH: ${(result.stdout as String).trim()}');
        return 'node';
      }
    } catch (_) {}

    // 2. Windows-specific fallback paths
    if (Platform.isWindows) {
      final candidates = [
        r'C:\Program Files\nodejs\node.exe',
        r'C:\Program Files (x86)\nodejs\node.exe',
        p.join(Platform.environment['APPDATA'] ?? '', r'npm\node.exe'),
        p.join(Platform.environment['ProgramFiles'] ?? '', r'nodejs\node.exe'),
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          debugPrint('✅ node encontrado en: $path');
          return path;
        }
      }
    }

    debugPrint('❌ No se encontró node.exe. Instala Node.js desde https://nodejs.org');
    return 'node'; // Last resort, will error with a clear message
  }

  /// Starts `node index.js` and `node simulador.js` in `backend_iot/`.
  /// Both processes pipe stdout/stderr to Flutter's debug console.
  /// Safe to call multiple times — skips if already running.
  Future<void> startServices() async {
    if (!_isDesktop) {
      debugPrint('ℹ️  BackendProcessManager: plataforma no-desktop, skipping.');
      return;
    }

    final backendDir = _backendDir();
    debugPrint('🚀 BackendProcessManager: iniciando servicios en $backendDir');

    _checkEnvFile(backendDir);

    final nodeExe = await _resolveNodeExecutable();

    _bridgeProcess ??= await _launch(nodeExe, ['index.js'], backendDir, '🌉 [Bridge]');
    _simuladorProcess ??= await _launch(nodeExe, ['simulador.js'], backendDir, '🤖 [Simulador]');
  }

  Future<Process?> _launch(
    String executable,
    List<String> args,
    String workingDir,
    String tag,
  ) async {
    final fullCmd = '$executable ${args.join(' ')}';
    debugPrint('▶️  $tag Ejecutando: $fullCmd');
    debugPrint('   en: $workingDir');

    try {
      final process = await Process.start(
        executable,
        args,
        workingDirectory: workingDir,
        // Inherit the parent process environment so APPDATA, PATH, etc. are available
        includeParentEnvironment: true,
        mode: ProcessStartMode.normal,
      );

      debugPrint('✅ $tag arrancado correctamente (PID: ${process.pid})');

      // Pipe stdout → Flutter debug console
      process.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) => debugPrint('$tag $line'));

      // Pipe stderr → Flutter debug console
      process.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) => debugPrint('$tag ⚠️ $line'));

      // Track unexpected exits
      process.exitCode.then((code) {
        if (code != 0) {
          debugPrint('⚠️ $tag proceso terminó con código $code');
          debugPrint('   Verifica los logs anteriores para detalles del error.');
        }
      });

      return process;
    } on ProcessException catch (e) {
      debugPrint('❌ $tag ProcessException: ${e.message}');
      debugPrint('   Ejecutable: $executable — Verifica que Node.js está instalado y en PATH.');
      return null;
    } catch (e) {
      debugPrint('❌ $tag Error inesperado: $e');
      return null;
    }
  }

  /// Gracefully terminates both Node.js processes.
  Future<void> stopServices() async {
    if (!_isDesktop) return;
    debugPrint('🛑 BackendProcessManager: deteniendo servicios...');
    await _kill(_bridgeProcess, '🌉 [Bridge]');
    await _kill(_simuladorProcess, '🤖 [Simulador]');
    _bridgeProcess = null;
    _simuladorProcess = null;
    debugPrint('🛑 BackendProcessManager: servicios detenidos.');
  }

  Future<void> _kill(Process? process, String tag) async {
    if (process == null) return;
    try {
      // Windows doesn't support SIGTERM — use kill() which sends SIGKILL
      process.kill();
      debugPrint('🛑 $tag detenido (PID: ${process.pid})');
    } catch (e) {
      debugPrint('$tag no se pudo detener: $e');
    }
  }
}
