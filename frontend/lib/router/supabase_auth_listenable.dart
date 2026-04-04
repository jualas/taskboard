import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notifica a [GoRouter.refreshListenable] cuando cambia la sesión de Supabase,
/// para que el redirect vuelva a evaluarse (evita pantallas protegidas sin JWT válido).
class SupabaseAuthListenable extends ChangeNotifier {
  SupabaseAuthListenable(SupabaseClient client) {
    _subscription = client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
