import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/models.dart';
import '../services/projects_service.dart';

// Events
abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();

  @override
  List<Object?> get props => [];
}

class ProjectsLoadRequested extends ProjectsEvent {}

class ProjectCreateRequested extends ProjectsEvent {
  final String title;
  final String description;

  const ProjectCreateRequested({
    required this.title,
    this.description = '',
  });

  @override
  List<Object> get props => [title, description];
}

class ProjectUpdateRequested extends ProjectsEvent {
  final Project project;

  const ProjectUpdateRequested(this.project);

  @override
  List<Object> get props => [project];
}

class ProjectDeleteRequested extends ProjectsEvent {
  final int id;

  const ProjectDeleteRequested(this.id);

  @override
  List<Object> get props => [id];
}

class ProjectStatusUpdateRequested extends ProjectsEvent {
  final int id;
  final ProjectStatus status;

  const ProjectStatusUpdateRequested({
    required this.id,
    required this.status,
  });

  @override
  List<Object> get props => [id, status];
}

// States
abstract class ProjectsState extends Equatable {
  const ProjectsState();

  @override
  List<Object?> get props => [];
}

class ProjectsInitial extends ProjectsState {}

class ProjectsLoading extends ProjectsState {}

class ProjectsLoaded extends ProjectsState {
  final List<Project> projects;

  const ProjectsLoaded(this.projects);

  @override
  List<Object> get props => [projects];
}

class ProjectsFailure extends ProjectsState {
  final String message;

  const ProjectsFailure(this.message);

  @override
  List<Object> get props => [message];
}

class ProjectOperationSuccess extends ProjectsState {
  final String message;

  const ProjectOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  final ProjectsService projectsService;

  ProjectsBloc({required this.projectsService}) : super(ProjectsInitial()) {
    on<ProjectsLoadRequested>(_onProjectsLoadRequested);
    on<ProjectCreateRequested>(_onProjectCreateRequested);
    on<ProjectUpdateRequested>(_onProjectUpdateRequested);
    on<ProjectDeleteRequested>(_onProjectDeleteRequested);
    on<ProjectStatusUpdateRequested>(_onProjectStatusUpdateRequested);
  }

  Future<void> _onProjectsLoadRequested(
    ProjectsLoadRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    
    try {
      final projects = await projectsService.getProjects();
      emit(ProjectsLoaded(projects));
    } catch (e) {
      final hint = e.toString().contains('Failed to fetch')
          ? ' (red o CORS: revisa URL del API, proxy mismo-origen y cabeceras del servidor).'
          : '';
      emit(ProjectsFailure('Error al cargar proyectos: $e$hint'));
    }
  }

  Future<void> _onProjectCreateRequested(
    ProjectCreateRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    
    try {
      await projectsService.createProject(
        title: event.title,
        description: event.description,
      );
      
      emit(const ProjectOperationSuccess('Proyecto creado correctamente'));
      add(ProjectsLoadRequested());
    } catch (e) {
      emit(ProjectsFailure('Error al crear proyecto: ${e.toString()}'));
    }
  }

  Future<void> _onProjectUpdateRequested(
    ProjectUpdateRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    
    try {
      await projectsService.updateProject(event.project);
      
      emit(const ProjectOperationSuccess('Proyecto actualizado correctamente'));
      add(ProjectsLoadRequested());
    } catch (e) {
      emit(ProjectsFailure('Error al actualizar proyecto: ${e.toString()}'));
    }
  }

  Future<void> _onProjectDeleteRequested(
    ProjectDeleteRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    
    try {
      await projectsService.deleteProject(event.id);
      
      emit(const ProjectOperationSuccess('Proyecto eliminado correctamente'));
      add(ProjectsLoadRequested());
    } catch (e) {
      emit(ProjectsFailure('Error al eliminar proyecto: ${e.toString()}'));
    }
  }

  Future<void> _onProjectStatusUpdateRequested(
    ProjectStatusUpdateRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(ProjectsLoading());
    
    try {
      await projectsService.updateProjectStatus(event.id, event.status);
      
      emit(const ProjectOperationSuccess('Estado del proyecto actualizado'));
      add(ProjectsLoadRequested());
    } catch (e) {
      emit(ProjectsFailure('Error al actualizar estado: ${e.toString()}'));
    }
  }
}
