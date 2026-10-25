import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Almacenamiento local del modo sin API: un único JSON en SharedPreferences
/// (`app_data`) con una lista por colección (`projects`, `tasks`).
///
/// No conoce las entidades: cada feature lee y escribe sus mapas JSON con su
/// propio modelo de `data/models/`. El formato es el que ya guardaba la app,
/// así que los datos locales existentes siguen siendo válidos.
class StorageService {
  static const String _dataKey = 'app_data';

  SharedPreferences? _prefs;
  Map<String, dynamic>? _cachedData;

  /// Preferencias tras [init]; null si aún no se ha inicializado.
  SharedPreferences? get prefs => _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs!.containsKey(_dataKey)) {
      final dataJson = await rootBundle.loadString('assets/data/data.json');
      await _prefs!.setString(_dataKey, dataJson);
    }
  }

  /// Configuración empaquetada en `assets/data/config.json` (sin caché).
  Future<AppConfig> getConfig() async {
    final configJson = await rootBundle.loadString('assets/data/config.json');
    final json = jsonDecode(configJson) as Map<String, dynamic>;
    return AppConfig.fromJson(json);
  }

  Map<String, dynamic> _data() {
    if (_cachedData != null) return _cachedData!;
    final jsonStr = _prefs!.getString(_dataKey);
    _cachedData = jsonStr == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
    return _cachedData!;
  }

  /// Copia de los elementos de una colección (lista vacía si no existe).
  List<Map<String, dynamic>> readCollection(String key) {
    final raw = _data()[key];
    if (raw is! List) return [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> writeCollection(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final data = Map<String, dynamic>.from(_data())..[key] = items;
    await _prefs!.setString(_dataKey, jsonEncode(data));
    _cachedData = data;
  }

  /// Siguiente id libre de una colección (máximo `id` + 1, o 1 si está vacía).
  int nextId(String key) {
    final ids = readCollection(key).map((e) => (e['id'] as num).toInt());
    return ids.isEmpty ? 1 : ids.reduce((a, b) => a > b ? a : b) + 1;
  }
}
