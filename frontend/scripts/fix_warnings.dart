import 'dart:io';
import 'package:flutter/foundation.dart';

void main() async {
  debugPrint('🔧 Corrigiendo warnings de estilo automáticamente...');

  // Lista de archivos a procesar
  final files = [
    'lib/main.dart',
    'lib/screens/dashboard/student_dashboard.dart',
    'lib/widgets/common/test_credentials_widget.dart',
    'lib/utils/config.dart',
    'lib/services/language_service.dart',
  ];

  for (final file in files) {
    if (await File(file).exists()) {
      await fixFile(file);
    }
  }

  debugPrint('✅ Corrección automática completada');
}

Future<void> fixFile(String filePath) async {
  debugPrint('📝 Procesando: $filePath');

  final file = File(filePath);
  String content = await file.readAsString();

  // Corregir prefer_int_literals
  content = content.replaceAll('16.0', '16');
  content = content.replaceAll('12.0', '12');
  content = content.replaceAll('8.0', '8');
  content = content.replaceAll('4.0', '4');
  content = content.replaceAll('24.0', '24');
  content = content.replaceAll('32.0', '32');
  content = content.replaceAll('30.0', '30');
  content = content.replaceAll('48.0', '48');
  content = content.replaceAll('50.0', '50');
  content = content.replaceAll('100.0', '100');
  content = content.replaceAll('80.0', '80');

  // Corregir prefer_expression_function_bodies simples
  content = content.replaceAllMapped(
    RegExp(
      r'@override\s+State<(\w+)> createState\(\)\s*{\s*return _\1State\(\);\s*}',
    ),
    (match) =>
        '@override\n  State<${match.group(1)}> createState() => _${match.group(1)}State();',
  );

  // Corregir funciones simples que pueden ser expresiones
  content = content.replaceAllMapped(
    RegExp(r'Widget _build(\w+)\(\)\s*{\s*return ([^;]+);\s*}'),
    (match) => 'Widget _build${match.group(1)}() => ${match.group(2)};',
  );

  await file.writeAsString(content);
  debugPrint('✅ Corregido: $filePath');
}
