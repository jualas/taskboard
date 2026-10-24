import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/features/tasks/data/models/task_model.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';

void main() {
  test('TaskModel.fromJson y toEntity conservan campos', () {
    final json = {
      'id': 1,
      'projectId': 10,
      'title': 'Demo',
      'description': 'Desc',
      'status': 'in_progress',
      'dueDate': null,
      'kanbanPosition': 2.5,
      'estimatedHours': 3,
      'complexity': 'medium',
      'tags': ['a'],
      'subtasks': [
        {'id': 1, 'title': 'Paso', 'isDone': false},
      ],
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-02T00:00:00.000',
    };

    final model = TaskModel.fromJson(json);
    final entity = model.toEntity();

    expect(entity.id, 1);
    expect(entity.projectId, 10);
    expect(entity.status, TaskStatus.inProgress);
    expect(entity.complexity, TaskComplexity.medium);
    expect(entity.subtasks, hasLength(1));

    final roundTrip = TaskModel.fromEntity(entity).toJson();
    expect(roundTrip['title'], 'Demo');
    expect(roundTrip['status'], 'in_progress');
  });
}
