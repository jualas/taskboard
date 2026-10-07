import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/projects_bloc.dart';
import '../models/models.dart';
import '../themes/app_theme.dart';
import 'open_in_cursor_button.dart';

Future<void> showWorkspaceInventorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return const _WorkspaceInventoryPanel();
    },
  );
}

class _WorkspaceInventoryPanel extends StatefulWidget {
  const _WorkspaceInventoryPanel();

  @override
  State<_WorkspaceInventoryPanel> createState() =>
      _WorkspaceInventoryPanelState();
}

enum _InventoryFilter { all, unlinked, linked }

class _WorkspaceInventoryPanelState extends State<_WorkspaceInventoryPanel> {
  WorkspaceInventory? _inventory;
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;
  _InventoryFilter _filter = _InventoryFilter.unlinked;
  int? _busyPathHash;

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
      final bloc = context.read<ProjectsBloc>();
      final service = bloc.projectsService;
      final results = await Future.wait([
        service.getWorkspaceInventory(),
        service.getProjects(),
      ]);
      if (!mounted) return;
      setState(() {
        _inventory = results[0] as WorkspaceInventory;
        _projects = results[1] as List<Project>;
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

  List<WorkspaceInventoryEntry> get _visibleEntries {
    final inv = _inventory;
    if (inv == null) return [];
    switch (_filter) {
      case _InventoryFilter.all:
        return inv.entries;
      case _InventoryFilter.unlinked:
        return inv.entries.where((e) => !e.isLinked).toList();
      case _InventoryFilter.linked:
        return inv.entries.where((e) => e.isLinked).toList();
    }
  }

  Future<void> _createProjectFor(WorkspaceInventoryEntry entry) async {
    setState(() => _busyPathHash = entry.path.hashCode);
    try {
      final service = context.read<ProjectsBloc>().projectsService;
      await service.createProject(
        title: _humanizeName(entry.name),
        workspacePath: entry.path,
      );
      context.read<ProjectsBloc>().add(ProjectsLoadRequested());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proyecto «${_humanizeName(entry.name)}» creado'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busyPathHash = null);
    }
  }

  Future<void> _linkToProject(
    WorkspaceInventoryEntry entry,
    Project project,
  ) async {
    setState(() => _busyPathHash = entry.path.hashCode);
    try {
      final service = context.read<ProjectsBloc>().projectsService;
      await service.updateProject(
        project.copyWith(workspacePath: entry.path, updatedAt: DateTime.now()),
      );
      context.read<ProjectsBloc>().add(ProjectsLoadRequested());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${project.title}» vinculado a ${entry.name}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busyPathHash = null);
    }
  }

  Future<void> _pickProjectToLink(WorkspaceInventoryEntry entry) async {
    final candidates = _projects
        .where((p) => p.canEdit && p.workspacePath.trim().isEmpty)
        .toList();
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay proyectos editables sin carpeta. Crea uno nuevo o libera un vínculo.',
          ),
        ),
      );
      return;
    }

    final picked = await showDialog<Project>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Vincular «${entry.name}»'),
        children: candidates
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p.title),
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      await _linkToProject(entry, picked);
    }
  }

  String _humanizeName(String folderName) {
    return folderName
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final inv = _inventory;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SizedBox(
      height: maxHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Inventario workspace',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (inv != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${inv.total} carpetas · ${inv.linked} vinculadas · ${inv.unlinked} sin vincular',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_InventoryFilter>(
              segments: const [
                ButtonSegment(
                  value: _InventoryFilter.unlinked,
                  label: Text('Sin vincular'),
                ),
                ButtonSegment(
                  value: _InventoryFilter.linked,
                  label: Text('Vinculadas'),
                ),
                ButtonSegment(
                  value: _InventoryFilter.all,
                  label: Text('Todas'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (s) {
                setState(() => _filter = s.first);
              },
            ),
          ),
          const SizedBox(height: 8),
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
                    : _buildList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final inv = _inventory!;
    final entries = _visibleEntries;

    if (entries.isEmpty && inv.orphanProjects.isEmpty) {
      return Center(
        child: Text(
          _filter == _InventoryFilter.unlinked
              ? 'Todas las carpetas detectadas ya están vinculadas.'
              : 'No hay entradas en este filtro.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        ...entries.map((e) => _entryTile(context, e)),
        if (inv.orphanProjects.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Proyectos con ruta no encontrada en el servidor',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...inv.orphanProjects.map(_orphanTile),
        ],
      ],
    );
  }

  Widget _entryTile(BuildContext context, WorkspaceInventoryEntry entry) {
    final busy = _busyPathHash == entry.path.hashCode;
    final badges = <Widget>[
      if (entry.hasGit)
        _chip(Icons.account_tree_outlined, 'git', context),
      if (entry.hasDockerCompose)
        _chip(Icons.view_in_ar_outlined, 'compose', context),
      Chip(
        label: Text(entry.root),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (entry.isLinked)
                  const Icon(Icons.link, size: 18, color: AppColors.success),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.path,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.isLinked && entry.linkedProjectTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                '→ ${entry.linkedProjectTitle}',
                style: const TextStyle(color: AppColors.accentPrimary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: badges),
            const SizedBox(height: 8),
            Row(
              children: [
                OpenInCursorIconButton(workspacePath: entry.path),
                const Spacer(),
                if (!entry.isLinked) ...[
                  TextButton(
                    onPressed: busy ? null : () => _pickProjectToLink(entry),
                    child: const Text('Vincular'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => _createProjectFor(entry),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear proyecto'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orphanTile(WorkspaceOrphanProject orphan) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
      title: Text(orphan.projectTitle),
      subtitle: Text(orphan.workspacePath, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _chip(IconData icon, String label, BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
