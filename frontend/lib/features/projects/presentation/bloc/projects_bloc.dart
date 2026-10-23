import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/project.dart';
import '../../domain/usecases/projects_usecases.dart';

abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();
  @override
  List<Object?> get props => [];
}

class ProjectsLoadRequested extends ProjectsEvent {}

class ProjectCreateRequested extends ProjectsEvent {
  const ProjectCreateRequested({required this.title, this.description = ''});
  final String title;
  final String description;
  @override
  List<Object> get props => [title, description];
}

class ProjectUpdateRequested extends ProjectsEvent {
  const ProjectUpdateRequested(this.project);
  final Project project;
  @override
  List<Object> get props => [project];
}

class ProjectDeleteRequested extends ProjectsEvent {
  const ProjectDeleteRequested(this.id);
  final int id;
  @override
  List<Object> get props => [id];
}

class ProjectStatusUpdateRequested extends ProjectsEvent {
  const ProjectStatusUpdateRequested({required this.id, required this.status});
  final int id;
  final ProjectStatus status;
  @override
  List<Object> get props => [id, status];
}

abstract class ProjectsState extends Equatable {
  const ProjectsState();
  @override
  List<Object?> get props => [];
}

class ProjectsInitial extends ProjectsState {}

class ProjectsLoading extends ProjectsState {}

class ProjectsLoaded extends ProjectsState {
  const ProjectsLoaded(this.projects);
  final List<Project> projects;
  @override
  List<Object> get props => [projects];
}

class ProjectsFailure extends ProjectsState {
  const ProjectsFailure(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}

class ProjectOperationSuccess extends ProjectsState {
  const ProjectOperationSuccess(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  ProjectsBloc({
    required this.getProjects,
    required this.createProject,
    required this.updateProject,
    required this.deleteProject,
    required this.updateProjectStatus,
    required this.getProject,
    required this.previewWorkspaceSnapshot,
    required this.getWorkspaceSuggestions,
    required this.applyWorkspaceSuggestion,
    required this.dismissWorkspaceSuggestion,
    required this.syncProjectWorkspace,
    required this.getWorkspaceInventory,
    required this.exportTaskboardMd,
    required this.prepareIdeSession,
    required this.getProjectMembers,
    required this.getRegisteredUsers,
    required this.addProjectMember,
    required this.updateProjectMemberRole,
    required this.removeProjectMember,
  }) : super(ProjectsInitial()) {
    on<ProjectsLoadRequested>(_onLoad);
    on<ProjectCreateRequested>(_onCreate);
    on<ProjectUpdateRequested>(_onUpdate);
    on<ProjectDeleteRequested>(_onDelete);
    on<ProjectStatusUpdateRequested>(_onStatus);
  }

  final GetProjects getProjects;
  final CreateProject createProject;
  final UpdateProject updateProject;
  final DeleteProject deleteProject;
  final UpdateProjectStatus updateProjectStatus;
  final GetProject getProject;
  final PreviewWorkspaceSnapshot previewWorkspaceSnapshot;
  final GetWorkspaceSuggestions getWorkspaceSuggestions;
  final ApplyWorkspaceSuggestion applyWorkspaceSuggestion;
  final DismissWorkspaceSuggestion dismissWorkspaceSuggestion;
  final SyncProjectWorkspace syncProjectWorkspace;
  final GetWorkspaceInventory getWorkspaceInventory;
  final ExportTaskboardMd exportTaskboardMd;
  final PrepareIdeSession prepareIdeSession;
  final GetProjectMembers getProjectMembers;
  final GetRegisteredUsers getRegisteredUsers;
  final AddProjectMember addProjectMember;
  final UpdateProjectMemberRole updateProjectMemberRole;
  final RemoveProjectMember removeProjectMember;

  String _msg(Result<dynamic> r, String prefix) =>
      '$prefix: ${r.failureOrNull?.message ?? 'error'}';

  Future<void> _onLoad(
    ProjectsLoadRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    final result = await getProjects(const NoParams());
    result.when(
      success: (projects) => emit(ProjectsLoaded(projects)),
      onFailure: (f) {
        final hint = f.message.contains('Failed to fetch')
            ? ' (red o CORS: revisa URL del API, proxy mismo-origen y cabeceras del servidor).'
            : '';
        emit(ProjectsFailure('Error al cargar proyectos: ${f.message}$hint'));
      },
    );
  }

  Future<void> _onCreate(
    ProjectCreateRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    final result = await createProject(
      CreateProjectParams(title: event.title, description: event.description),
    );
    if (result.isFailure) {
      emit(ProjectsFailure(_msg(result, 'Error al crear proyecto')));
      return;
    }
    emit(const ProjectOperationSuccess('Proyecto creado correctamente'));
    add(ProjectsLoadRequested());
  }

  Future<void> _onUpdate(
    ProjectUpdateRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    final result = await updateProject(event.project);
    if (result.isFailure) {
      emit(ProjectsFailure(_msg(result, 'Error al actualizar proyecto')));
      return;
    }
    emit(const ProjectOperationSuccess('Proyecto actualizado correctamente'));
    add(ProjectsLoadRequested());
  }

  Future<void> _onDelete(
    ProjectDeleteRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    final result = await deleteProject(event.id);
    if (result.isFailure) {
      emit(ProjectsFailure(_msg(result, 'Error al eliminar proyecto')));
      return;
    }
    emit(const ProjectOperationSuccess('Proyecto eliminado correctamente'));
    add(ProjectsLoadRequested());
  }

  Future<void> _onStatus(
    ProjectStatusUpdateRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    final result = await updateProjectStatus(
      UpdateProjectStatusParams(id: event.id, status: event.status),
    );
    if (result.isFailure) {
      emit(ProjectsFailure(_msg(result, 'Error al actualizar estado')));
      return;
    }
    emit(const ProjectOperationSuccess('Estado del proyecto actualizado'));
    add(ProjectsLoadRequested());
  }
}
