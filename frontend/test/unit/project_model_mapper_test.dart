import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/features/projects/data/models/project_model.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project_member.dart';

void main() {
  test('ProjectModel.fromJson y toEntity conservan campos', () {
    final json = {
      'id': 7,
      'title': 'Tablero',
      'description': 'Desc',
      'status': 'development',
      'ownerId': 'user-1',
      'currentUserRole': 'editor',
      'workspacePath': '/work/tablero',
      'pendingWorkspaceSuggestions': 2,
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-02T00:00:00.000',
    };

    final entity = ProjectModel.fromJson(json).toEntity();
    expect(entity.id, 7);
    expect(entity.status, ProjectStatus.development);
    expect(entity.currentUserRole, ProjectMemberRole.editor);
    expect(entity.workspacePath, '/work/tablero');
    expect(entity.pendingWorkspaceSuggestions, 2);

    final roundTrip = ProjectModel.fromEntity(entity).toJson();
    expect(roundTrip['title'], 'Tablero');
    expect(roundTrip['status'], 'development');
    expect(roundTrip['currentUserRole'], 'editor');
  });
}
