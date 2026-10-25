import 'package:equatable/equatable.dart';

import 'ai_task_suggestion.dart';

/// Nombre visible del proveedor IA que respondió.
String aiProviderLabel(String? provider) {
  switch (provider) {
    case 'cursor_agent':
      return 'Cursor Agent';
    case 'deepseek':
      return 'DeepSeek (nube)';
    case 'local':
      return 'Ollama (local)';
    default:
      return 'IA';
  }
}

class AiChatMessage extends Equatable {
  const AiChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  @override
  List<Object?> get props => [role, content];
}

/// Respuesta del chat de planificación. `tasks` es null si la IA no cambió el borrador.
class AiChatReply extends Equatable {
  const AiChatReply({
    required this.message,
    required this.tasks,
    this.provider,
  });

  final String message;
  final List<AiTaskSuggestion>? tasks;
  final String? provider;

  String get providerLabel => aiProviderLabel(provider);

  @override
  List<Object?> get props => [message, tasks, provider];
}

class AiSuggestionResult extends Equatable {
  const AiSuggestionResult({required this.suggestions, this.provider});

  final List<AiTaskSuggestion> suggestions;
  final String? provider;

  String get providerLabel => aiProviderLabel(provider);

  @override
  List<Object?> get props => [suggestions, provider];
}
