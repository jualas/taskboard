import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
/// Comprueba reglas de Clean Architecture en lib/features/**/domain y presentation.
void main() {
  final libDir = Directory('lib/features');

  test('domain no importa Flutter, HTTP, JSON ni capas externas', () {
    if (!libDir.existsSync()) {
      return;
    }

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (!entity.path.contains('/domain/') &&
          !entity.path.contains(r'\domain\')) {
        continue;
      }

      final content = entity.readAsStringSync();
      final rel = entity.path;
      for (final banned in [
        'package:flutter/',
        'package:http/',
        'json_annotation',
        'shared_preferences',
        '/data/',
        '/presentation/',
      ]) {
        if (content.contains(banned)) {
          violations.add('$rel → $banned');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('presentation no importa data (salvo comentarios)', () {
    if (!libDir.existsSync()) {
      return;
    }

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (!entity.path.contains('/presentation/') &&
          !entity.path.contains(r'\presentation\')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      final rel = entity.path;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('//')) {
          continue;
        }
        if (trimmed.contains("import '") || trimmed.contains('import "')) {
          if (trimmed.contains('/data/') &&
              !trimmed.contains('core/di')) {
            violations.add('$rel → $trimmed');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('screens y widgets no importan data ni usan sl<>', () {
    final violations = <String>[];
    for (final root in ['lib/screens', 'lib/widgets']) {
      final dir = Directory(root);
      if (!dir.existsSync()) {
        continue;
      }
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final lines = entity.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('//')) {
          continue;
        }
          if ((trimmed.contains("import '") || trimmed.contains('import "')) &&
              trimmed.contains('/data/')) {
            violations.add('${entity.path} → $trimmed');
          }
          if (trimmed.contains('sl<')) {
            violations.add('${entity.path} → $trimmed');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
