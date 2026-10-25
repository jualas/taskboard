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
          if (trimmed.contains('/data/') && !trimmed.contains('core/di')) {
            violations.add('$rel → $trimmed');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('lib/ solo tiene core, features, shared y main.dart', () {
    final entries = Directory('lib')
        .listSync()
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    expect(
      entries.difference({'core', 'features', 'shared', 'main.dart'}),
      isEmpty,
      reason:
          'Las carpetas heredadas (blocs, models, services, screens, '
          'widgets, utils) se eliminaron en CA-6; el código va en features/.',
    );
  });

  test('core no importa features (salvo core/di)', () {
    final violations = <String>[];
    for (final entity in Directory('lib/core').listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path.contains('/core/di/')) {
        continue;
      }
      for (final line in entity.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.startsWith('import ') && trimmed.contains('features/')) {
          violations.add('${entity.path} → $trimmed');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
