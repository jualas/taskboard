import 'package:flutter_test/flutter_test.dart';

import 'package:personal_taskboard/models/task.dart';

Map<String, dynamic> _taskJson(String complexity) => {
      'id': 1,
      'projectId': 7,
      'title': 'Tarea',
      'description': '',
      'status': 'pending',
      'kanbanPosition': 1.0,
      'complexity': complexity,
      'tags': <String>[],
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    };

void main() {
  test('una complejidad desconocida no rompe la carga (cae a medium)', () {
    expect(Task.fromJson(_taskJson('media')).complexity, TaskComplexity.medium);
  });

  test('las complejidades válidas se leen tal cual', () {
    expect(Task.fromJson(_taskJson('complex')).complexity, TaskComplexity.complex);
  });
}
