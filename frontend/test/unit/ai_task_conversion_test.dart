import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/features/ai_assistant/data/models/agent_session_model.dart';
import 'package:personal_taskboard/features/ai_assistant/data/models/ai_task_suggestion_model.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_task_suggestion.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/services/ai_task_conversion.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';

AiTaskSuggestion _s(String title, {List<String> subtasks = const []}) =>
    AiTaskSuggestion(
      title: title,
      description: '',
      complexity: TaskComplexity.medium,
      estimatedHours: null,
      tags: const [],
      subtasks: subtasks,
    );

void main() {
  group('reglas de dominio', () {
    test(
      'newTasksInDraft ignora títulos existentes sin distinguir mayúsculas ni espacios',
      () {
        final result = newTasksInDraft(
          draft: [_s('  Login '), _s('Exportar CSV'), _s('   ')],
          baseline: [_s('login')],
        );
        expect(result.map((t) => t.title), ['Exportar CSV']);
      },
    );

    test('aiSuggestionFromTask copia los campos de la tarea', () {
      final t = DateTime(2026, 1, 1);
      final task = Task(
        id: 1,
        projectId: 2,
        title: 'T',
        description: 'D',
        status: TaskStatus.pending,
        kanbanPosition: 0,
        estimatedHours: 3,
        complexity: TaskComplexity.complex,
        tags: const ['a'],
        subtasks: const [Subtask(id: 1, title: 'paso')],
        createdAt: t,
        updatedAt: t,
      );
      expect(
        aiSuggestionFromTask(task),
        const AiTaskSuggestion(
          title: 'T',
          description: 'D',
          complexity: TaskComplexity.complex,
          estimatedHours: 3,
          tags: ['a'],
          subtasks: ['paso'],
        ),
      );
    });

    test('subtasksFromAiSuggestion numera desde 1 y sin marcar', () {
      expect(subtasksFromAiSuggestion(_s('x', subtasks: ['a', 'b'])), const [
        Subtask(id: 1, title: 'a'),
        Subtask(id: 2, title: 'b'),
      ]);
    });
  });

  group('AiTaskSuggestionModel', () {
    test(
      'acepta snake_case, checklist de objetos y complejidad en español',
      () {
        final s = AiTaskSuggestionModel.fromJson({
          'Title': ' Tarea ',
          'description': 'desc',
          'complexity': 'Compleja',
          'estimated_hours': '4',
          'tags': ['ui', ' ', 'api'],
          'checklist': [
            {'text': 'uno'},
            'dos',
            {'other': 'x'},
          ],
        }).entity;
        expect(s.title, 'Tarea');
        expect(s.complexity, TaskComplexity.complex);
        expect(s.estimatedHours, 4);
        expect(s.tags, ['ui', 'api']);
        expect(s.subtasks, ['uno', 'dos']);
      },
    );

    test('usa acceptanceCriteria si no hay subtareas y medium por defecto', () {
      final s = AiTaskSuggestionModel.fromJson({
        'title': 't',
        'acceptanceCriteria': ['c1'],
      }).entity;
      expect(s.subtasks, ['c1']);
      expect(s.complexity, TaskComplexity.medium);
      expect(s.estimatedHours, isNull);
    });

    test('listFromJson descarta elementos sin título o que no son objeto', () {
      final list = AiTaskSuggestionModel.listFromJson([
        {'title': 'ok'},
        {'title': ''},
        'texto',
        {'title': 'otra', 'estimatedHours': 2},
      ]);
      expect(list.map((t) => t.title), ['ok', 'otra']);
    });

    test('toJson envía la complejidad por nombre', () {
      expect(AiTaskSuggestionModel(_s('t')).toJson()['complexity'], 'medium');
    });
  });

  test('AgentSessionModel y AgentRunModel leen el JSON del API', () {
    final session = AgentSessionModel.fromJson({
      'project_id': 7,
      'session_id': 'abcdef123456',
      'updated_at': '2026-10-25T10:00:00Z',
    });
    expect(session.shortId, 'abcdef12');
    expect(session.workspacePath, '');

    final run = AgentRunModel.fromJson({
      'id': 1,
      'project_id': 7,
      'prompt': 'hola',
      'execute_mode': true,
      'created_at': '2026-10-25T10:00:00Z',
    });
    expect(run.executeMode, isTrue);
    expect(run.isError, isFalse);
    expect(run.sessionId, isNull);
  });
}
