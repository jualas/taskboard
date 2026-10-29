import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/agent_session.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_chat.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project_member.dart';
import 'package:personal_taskboard/features/projects/domain/entities/workspace.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';

void main() {
  test('estado y complejidad de tarea: ida y vuelta con el valor del API', () {
    for (final s in TaskStatus.values) {
      expect(taskStatusFromDb(s.dbValue), s);
      expect(s.displayName, isNotEmpty);
    }
    for (final c in TaskComplexity.values) {
      expect(taskComplexityFromDb(c.dbValue), c);
      expect(c.displayName, isNotEmpty);
    }
    expect(taskStatusFromDb('desconocido'), TaskStatus.pending);
    expect(taskComplexityFromDb('desconocido'), TaskComplexity.simple);
    expect(TaskStatus.inProgress.isInProgress, isTrue);
    expect(TaskStatus.completed.isCompleted, isTrue);
    expect(TaskStatus.pending.isPending, isTrue);
  });

  test('Task.copyWith y orden por posición kanban', () {
    final t = DateTime(2026, 1, 1);
    final a = Task(
      id: 1,
      projectId: 1,
      title: 'a',
      description: '',
      status: TaskStatus.pending,
      kanbanPosition: 2,
      complexity: TaskComplexity.simple,
      tags: const [],
      createdAt: t,
      updatedAt: t,
    );
    final b = a.copyWith(
      id: 2,
      kanbanPosition: 1,
      status: TaskStatus.completed,
    );
    expect(b.title, 'a');
    expect(b.status, TaskStatus.completed);
    expect(([a, b]..sort(compareTasksByKanbanPosition)).first.id, 2);
    const s = Subtask(id: 1, title: 'x');
    expect(s.copyWith(isDone: true).isDone, isTrue);
  });

  test('roles de miembro y permiso de edición', () {
    for (final r in ProjectMemberRole.values) {
      expect(projectMemberRoleFromDb(r.dbValue), r);
      expect(r.displayName, isNotEmpty);
    }
    expect(projectMemberRoleFromDb('raro'), ProjectMemberRole.editor);
    expect(ProjectMemberRole.viewer.canEdit, isFalse);
    expect(ProjectMemberRole.editor.canEdit, isTrue);

    final p = Project.create(id: 1, title: 'P');
    expect(p.status, ProjectStatus.planning);
    expect(p.canEdit, isTrue, reason: 'sin rol (modo local) se puede editar');
    expect(
      p.copyWith(currentUserRole: ProjectMemberRole.viewer).canEdit,
      isFalse,
    );
  });

  test('tipo de sugerencia de workspace', () {
    WorkspaceSuggestion s(String type) => WorkspaceSuggestion(
      id: 1,
      projectId: 1,
      suggestionType: type,
      title: 't',
      createdAt: DateTime(2026, 1, 1),
    );
    expect(s('task').isTask, isTrue);
    expect(s('project_status').isProjectStatus, isTrue);
    expect(s('info').isInfo, isTrue);
    expect(s('task').typeLabel, 'Tarea sugerida');
    expect(s('otro').typeLabel, 'Información');
  });

  test('proveedor IA y sesión agent', () {
    expect(aiProviderLabel('claude_code'), 'Claude Code');
    expect(aiProviderLabel('deepseek'), 'DeepSeek (nube)');
    expect(aiProviderLabel(null), 'IA');
    final session = AgentSession(
      projectId: 1,
      sessionId: 'abc',
      updatedAt: DateTime(2026, 1, 1),
    );
    expect(session.shortId, 'abc');
  });
}
