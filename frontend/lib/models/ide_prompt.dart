/// Plantilla de prompt para sesión de desarrollo en Cursor IDE.
class IdePrompt {
  const IdePrompt({
    required this.projectId,
    required this.projectTitle,
    required this.workspacePath,
    required this.taskboardMd,
    required this.statusMdPaths,
    required this.fileReferences,
    required this.prompt,
    required this.taskCounts,
    this.focusTaskId,
    this.focusTaskTitle,
  });

  final int projectId;
  final String projectTitle;
  final String workspacePath;
  final String taskboardMd;
  final List<String> statusMdPaths;
  final List<String> fileReferences;
  final int? focusTaskId;
  final String? focusTaskTitle;
  final String prompt;
  final Map<String, int> taskCounts;

  factory IdePrompt.fromJson(Map<String, dynamic> json) {
    final countsRaw = json['task_counts'] ?? json['taskCounts'];
    final counts = <String, int>{};
    if (countsRaw is Map) {
      countsRaw.forEach((k, v) {
        if (v is num) counts[k.toString()] = v.toInt();
      });
    }
    final refs = json['file_references'] ?? json['fileReferences'];
    return IdePrompt(
      projectId: (json['project_id'] as num).toInt(),
      projectTitle: json['project_title'] as String? ?? '',
      workspacePath: json['workspace_path'] as String? ?? '',
      taskboardMd: json['taskboard_md'] as String? ?? 'TASKBOARD.md',
      statusMdPaths: (json['status_md_paths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fileReferences:
          refs is List ? refs.map((e) => e.toString()).toList() : [],
      focusTaskId: (json['focus_task_id'] as num?)?.toInt(),
      focusTaskTitle: json['focus_task_title'] as String?,
      prompt: json['prompt'] as String? ?? '',
      taskCounts: counts,
    );
  }
}
