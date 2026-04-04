import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/blocs.dart';
import '../../models/models.dart';
import '../../themes/app_theme.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  bool _isUpdatingMembers = false;
  @override
  void initState() {
    super.initState();
    context.read<ProjectsBloc>().add(ProjectsLoadRequested());
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final auth = context.read<AuthBloc>().authService;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas nuevas no coinciden'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              if (newCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La nueva contraseña no puede estar vacía'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              try {
                await auth.changePassword(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contraseña actualizada'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Proyectos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ProjectsBloc>().add(ProjectsLoadRequested());
            },
            tooltip: 'Actualizar',
          ),
          PopupMenuButton<String>(
            tooltip: 'Cuenta',
            onSelected: (value) {
              if (value == 'password') {
                _showChangePasswordDialog();
              } else if (value == 'logout') {
                context.read<AuthBloc>().add(AuthLogoutRequested());
                context.go('/login');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'password',
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Cambiar contraseña'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<ProjectsBloc, ProjectsState>(
        listener: (context, state) {
          if (state is ProjectsFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is ProjectOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProjectsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is ProjectsLoaded) {
            if (state.projects.isEmpty) {
              return _buildEmptyState();
            }
            return _buildProjectsList(state.projects);
          }

          return _buildEmptyState();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Proyecto'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes proyectos aún',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primer proyecto para comenzar',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateProjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('Crear Proyecto'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList(List<Project> projects) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          return _buildProjectCard(projects[index]);
        },
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final statusColor = _getStatusColor(project.status);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/projects/${project.id}/kanban'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      project.status.displayName,
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) => _handleProjectAction(value, project),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'kanban',
                        child: Row(
                          children: [
                            Icon(Icons.view_kanban),
                            SizedBox(width: 8),
                            Text('Ver Kanban'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'list',
                        child: Row(
                          children: [
                            Icon(Icons.list),
                            SizedBox(width: 8),
                            Text('Ver Lista'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      if (project.canEdit)
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.group_add),
                              SizedBox(width: 8),
                              Text('Compartir'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: ClipRect(
                        child: Text(
                          project.description.isEmpty
                              ? 'Sin descripción'
                              : project.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: project.description.isEmpty
                                ? AppColors.textSecondary.withValues(alpha: 0.5)
                                : null,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (project.description.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showProjectDescription(project),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Ver descripción'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          project.currentUserRole?.displayName ?? 'Sin rol',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(project.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planning:
        return AppColors.warning;
      case ProjectStatus.development:
        return AppColors.accentPrimary;
      case ProjectStatus.completed:
        return AppColors.success;
      case ProjectStatus.archived:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleProjectAction(String action, Project project) {
    switch (action) {
      case 'kanban':
        context.go('/projects/${project.id}/kanban');
        break;
      case 'list':
        context.go('/projects/${project.id}/tasks');
        break;
      case 'edit':
        if (project.canEdit) {
          _showEditProjectDialog(project);
        } else {
          _showPermissionError();
        }
        break;
      case 'delete':
        if (project.canEdit) {
          _showDeleteConfirmation(project);
        } else {
          _showPermissionError();
        }
        break;
      case 'share':
        _showShareProjectDialog(project);
        break;
    }
  }

  void _showPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No tienes permisos de edición en este proyecto'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showCreateProjectDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Proyecto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Nombre del proyecto',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Descripción opcional',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                context.read<ProjectsBloc>().add(
                  ProjectCreateRequested(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showEditProjectDialog(Project project) {
    final titleController = TextEditingController(text: project.title);
    final descriptionController = TextEditingController(text: project.description);
    ProjectStatus selectedStatus = project.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Proyecto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProjectStatus>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                ),
                items: ProjectStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedStatus = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  context.read<ProjectsBloc>().add(
                    ProjectUpdateRequested(
                      project.copyWith(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        status: selectedStatus,
                      ),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Proyecto'),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${project.title}"?\n\n'
          'Esta acción también eliminará todas las tareas del proyecto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ProjectsBloc>().add(
                ProjectDeleteRequested(project.id),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showShareProjectDialog(Project project) async {
    ProjectMemberRole selectedRole = ProjectMemberRole.viewer;
    final projectsService = context.read<ProjectsBloc>().projectsService;
    List<ProjectMember> members = [];
    List<AppUser> users = [];
    String? selectedUserId;

    String labelForUser(String userId) {
      AppUser? user;
      for (final candidate in users) {
        if (candidate.id == userId) {
          user = candidate;
          break;
        }
      }
      if (user == null) return userId;
      return '${user.email} (${user.id.substring(0, 8)}...)';
    }

    Future<void> reloadMembers(StateSetter setStateModal) async {
      final loadedMembers = await projectsService.getProjectMembers(project.id);
      setStateModal(() {
        members = loadedMembers;
      });
    }

    try {
      members = await projectsService.getProjectMembers(project.id);
      users = await projectsService.getRegisteredUsers();
    } catch (_) {
      // La UI ya muestra errores en operaciones; aquí evitamos bloquear el modal.
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: Text('Compartir: ${project.title}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(labelForUser(member.userId)),
                        subtitle: Text(member.role.displayName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<ProjectMemberRole>(
                              value: member.role,
                              onChanged: member.role == ProjectMemberRole.owner
                                  ? null
                                  : (role) async {
                                      if (role == null) return;
                                      setStateModal(() {
                                        _isUpdatingMembers = true;
                                      });
                                      try {
                                        await projectsService.updateMemberRole(
                                          projectId: project.id,
                                          userId: member.userId,
                                          role: role,
                                        );
                                        await reloadMembers(setStateModal);
                                      } finally {
                                        if (mounted) {
                                          setStateModal(() {
                                            _isUpdatingMembers = false;
                                          });
                                        }
                                      }
                                    },
                              items: ProjectMemberRole.values
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role.displayName),
                                    ),
                                  )
                                  .toList(),
                            ),
                            if (member.role != ProjectMemberRole.owner)
                              IconButton(
                                tooltip: 'Quitar acceso',
                                onPressed: _isUpdatingMembers
                                    ? null
                                    : () async {
                                        setStateModal(() {
                                          _isUpdatingMembers = true;
                                        });
                                        try {
                                          await projectsService.removeMember(
                                            projectId: project.id,
                                            userId: member.userId,
                                          );
                                          await reloadMembers(setStateModal);
                                        } finally {
                                          if (mounted) {
                                            setStateModal(() {
                                              _isUpdatingMembers = false;
                                            });
                                          }
                                        }
                                      },
                                icon: const Icon(
                                  Icons.person_remove,
                                  color: AppColors.error,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Usuario registrado',
                  ),
                  items: users
                      .where(
                        (user) =>
                            !members.any((member) => member.userId == user.id),
                      )
                      .map(
                        (user) => DropdownMenuItem(
                          value: user.id,
                          child: Text(
                            '${user.email} (${user.id.substring(0, 8)}...)',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setStateModal(() {
                      selectedUserId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProjectMemberRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: ProjectMemberRole.values
                      .where((role) => role != ProjectMemberRole.owner)
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (role) {
                    if (role != null) {
                      setStateModal(() => selectedRole = role);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: _isUpdatingMembers
                  ? null
                  : () async {
                      final userId = selectedUserId;
                      if (userId == null || userId.isEmpty) return;
                      setStateModal(() {
                        _isUpdatingMembers = true;
                      });
                      try {
                        await projectsService.addMember(
                          projectId: project.id,
                          userId: userId,
                          role: selectedRole,
                        );
                        selectedUserId = null;
                        await reloadMembers(setStateModal);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No se pudo compartir: ${e.toString()}'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setStateModal(() {
                            _isUpdatingMembers = false;
                          });
                        }
                      }
                    },
              icon: const Icon(Icons.person_add),
              label: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      context.read<ProjectsBloc>().add(ProjectsLoadRequested());
    }
  }

  void _showProjectDescription(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(project.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
          child: SingleChildScrollView(
            child: Text(
              project.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
