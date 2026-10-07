/// Sugerencia automática generada a partir del workspace (Fase 2).
class WorkspaceSuggestion {
  final int id;
  final int projectId;
  final int? snapshotId;
  final String suggestionType;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final String state;
  final DateTime createdAt;

  const WorkspaceSuggestion({
    required this.id,
    required this.projectId,
    this.snapshotId,
    required this.suggestionType,
    required this.title,
    this.body = '',
    this.payload = const {},
    this.state = 'pending',
    required this.createdAt,
  });

  factory WorkspaceSuggestion.fromApi(Map<String, dynamic> m) {
    final payloadRaw = m['payload'];
    Map<String, dynamic> payload = {};
    if (payloadRaw is Map) {
      payload = Map<String, dynamic>.from(payloadRaw);
    }
    return WorkspaceSuggestion(
      id: (m['id'] as num).toInt(),
      projectId: (m['project_id'] as num).toInt(),
      snapshotId: (m['snapshot_id'] as num?)?.toInt(),
      suggestionType: m['suggestion_type'] as String? ?? 'info',
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      payload: payload,
      state: m['state'] as String? ?? 'pending',
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  bool get isInfo => suggestionType == 'info';
  bool get isProjectStatus => suggestionType == 'project_status';
  bool get isTask => suggestionType == 'task';

  String get typeLabel {
    switch (suggestionType) {
      case 'project_status':
        return 'Estado del proyecto';
      case 'task':
        return 'Nueva tarea';
      default:
        return 'Aviso';
    }
  }
}
