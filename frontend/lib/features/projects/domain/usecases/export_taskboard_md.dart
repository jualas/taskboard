import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/workspace.dart';
import '../repositories/projects_repository.dart';

class ExportTaskboardMd implements UseCase<TaskboardExport, ExportTaskboardMdParams> {
  ExportTaskboardMd(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<TaskboardExport>> call(ExportTaskboardMdParams p) =>
      _repo.exportTaskboardMd(
        p.projectId,
        dryRun: p.dryRun,
        filename: p.filename,
      );
}

class ExportTaskboardMdParams {
  const ExportTaskboardMdParams({
    required this.projectId,
    this.dryRun = false,
    this.filename = '',
  });
  final int projectId;
  final bool dryRun;
  final String filename;
}
