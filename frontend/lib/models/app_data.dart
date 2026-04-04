import 'package:json_annotation/json_annotation.dart';
import 'project.dart';
import 'task.dart';

part 'app_data.g.dart';

/// Modelo que representa todos los datos de la aplicación.
@JsonSerializable()
class AppData {
  final List<Project> projects;
  final List<Task> tasks;

  const AppData({
    required this.projects,
    required this.tasks,
  });

  factory AppData.fromJson(Map<String, dynamic> json) => _$AppDataFromJson(json);
  Map<String, dynamic> toJson() => _$AppDataToJson(this);

  /// Crea una instancia vacía
  factory AppData.empty() {
    return const AppData(projects: [], tasks: []);
  }

  /// Crea una copia con proyectos actualizados
  AppData copyWithProjects(List<Project> newProjects) {
    return AppData(projects: newProjects, tasks: tasks);
  }

  /// Crea una copia con tareas actualizadas
  AppData copyWithTasks(List<Task> newTasks) {
    return AppData(projects: projects, tasks: newTasks);
  }

  /// Obtiene las tareas de un proyecto específico
  List<Task> getTasksForProject(int projectId) {
    return tasks.where((task) => task.projectId == projectId).toList();
  }

  /// Obtiene el siguiente ID disponible para proyectos
  int get nextProjectId {
    if (projects.isEmpty) return 1;
    return projects.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Obtiene el siguiente ID disponible para tareas
  int get nextTaskId {
    if (tasks.isEmpty) return 1;
    return tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}
