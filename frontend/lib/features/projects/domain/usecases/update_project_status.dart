import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project.dart';
import '../repositories/projects_repository.dart';

class UpdateProjectStatus implements UseCase<Project, UpdateProjectStatusParams> {
  UpdateProjectStatus(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project>> call(UpdateProjectStatusParams p) async {
    final current = await _repo.getProject(p.id);
    switch (current) {
      case ResultFailure(:final failure):
        return ResultFailure(failure);
      case Success(:final value):
        if (value == null) {
          return const ResultFailure(NotFoundFailure('Proyecto no encontrado'));
        }
        return _repo.updateProject(
          value.copyWith(status: p.status, updatedAt: DateTime.now()),
        );
    }
  }
}

class UpdateProjectStatusParams {
  const UpdateProjectStatusParams({required this.id, required this.status});
  final int id;
  final ProjectStatus status;
}
