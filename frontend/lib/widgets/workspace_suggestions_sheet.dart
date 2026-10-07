import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/projects_bloc.dart';
import '../blocs/tasks_bloc.dart';
import '../models/models.dart';
import '../themes/app_theme.dart';
import 'open_in_cursor_button.dart';

Future<void> showWorkspaceSuggestionsSheet(
  BuildContext context, {
  required Project project,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _WorkspaceSuggestionsPanel(project: project);
    },
  );
}

class _WorkspaceSuggestionsPanel extends StatefulWidget {
  const _WorkspaceSuggestionsPanel({required this.project});

  final Project project;

  @override
  State<_WorkspaceSuggestionsPanel> createState() =>
      _WorkspaceSuggestionsPanelState();
}

class _WorkspaceSuggestionsPanelState extends State<_WorkspaceSuggestionsPanel> {
  List<WorkspaceSuggestion> _suggestions = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<ProjectsBloc>().projectsService;
      final items = await service.getWorkspaceSuggestions(widget.project.id);
      if (!mounted) return;
      setState(() {
        _suggestions = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final service = context.read<ProjectsBloc>().projectsService;
      await service.syncProjectWorkspace(widget.project.id);
      context.read<ProjectsBloc>().add(ProjectsLoadRequested());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace sincronizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al sincronizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _apply(WorkspaceSuggestion s) async {
    setState(() => _busyId = s.id);
    try {
      final service = context.read<ProjectsBloc>().projectsService;
      await service.applyWorkspaceSuggestion(widget.project.id, s.id);
      context.read<ProjectsBloc>().add(ProjectsLoadRequested());
      if (s.isTask) {
        try {
          context.read<TasksBloc>().add(
                TasksLoadRequested(projectId: widget.project.id),
              );
        } catch (_) {}
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${s.title}» aplicada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aplicar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _dismiss(WorkspaceSuggestion s) async {
    setState(() => _busyId = s.id);
    try {
      final service = context.read<ProjectsBloc>().projectsService;
      await service.dismissWorkspaceSuggestion(widget.project.id, s.id);
      context.read<ProjectsBloc>().add(ProjectsLoadRequested());
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return SizedBox(
      height: maxH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sugerencias del workspace',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        widget.project.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _syncing ? null : _syncNow,
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sincronizar'),
                ),
                if (widget.project.workspacePath.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => OpenInCursorAction.show(
                      context,
                      workspacePath: widget.project.workspacePath,
                      projectTitle: widget.project.title,
                    ),
                    icon: const Icon(Icons.terminal),
                    label: const Text('Cursor'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      )
                    : _suggestions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                widget.project.workspacePath.isEmpty
                                    ? 'Vincula una carpeta workspace en Editar proyecto.'
                                    : 'Sin sugerencias pendientes.\n'
                                        'El API revisa el repo cada ~30 min o pulsa Sincronizar.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final s = _suggestions[index];
                              final busy = _busyId == s.id;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text(
                                              s.typeLabel,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          const Spacer(),
                                          if (busy)
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        s.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      if (s.body.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          s.body,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                      if (widget.project.canEdit) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: busy
                                                  ? null
                                                  : () => _dismiss(s),
                                              child: const Text('Descartar'),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton(
                                              onPressed: busy || s.isInfo
                                                  ? (busy
                                                      ? null
                                                      : () => _dismiss(s))
                                                  : () => _apply(s),
                                              child: Text(
                                                s.isInfo ? 'Entendido' : 'Aplicar',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
