import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/projects_service.dart';
import '../themes/app_theme.dart';
import '../ui/root_scaffold_messenger.dart';
import 'open_in_cursor_button.dart';

/// Prepara TASKBOARD.md + plantilla de prompt y la muestra para copiar al IDE.
Future<void> showIdeCursorSessionSheet(
  BuildContext context, {
  required ProjectsService projectsService,
  required Project project,
  int? focusTaskId,
}) async {
  if (project.workspacePath.isEmpty) {
    kRootScaffoldMessenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Este proyecto no tiene carpeta workspace vinculada.'),
        backgroundColor: AppColors.warning,
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _IdeCursorSessionSheet(
      projectsService: projectsService,
      project: project,
      focusTaskId: focusTaskId,
    ),
  );
}

class _IdeCursorSessionSheet extends StatefulWidget {
  const _IdeCursorSessionSheet({
    required this.projectsService,
    required this.project,
    this.focusTaskId,
  });

  final ProjectsService projectsService;
  final Project project;
  final int? focusTaskId;

  @override
  State<_IdeCursorSessionSheet> createState() => _IdeCursorSessionSheetState();
}

class _IdeCursorSessionSheetState extends State<_IdeCursorSessionSheet> {
  IdePrompt? _prompt;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.projectsService.prepareIdeSession(
        widget.project.id,
        focusTaskId: widget.focusTaskId,
      );
      if (!mounted) return;
      setState(() {
        _prompt = p;
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

  Future<void> _copyPrompt() async {
    final text = _prompt?.prompt ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    kRootScaffoldMessenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Prompt copiado al portapapeles. Pégalo en Cursor (Chat o Agent).'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: AppColors.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sesión IDE (Cursor)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.project.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _prepare, child: const Text('Reintentar')),
                    ],
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WorkflowSteps(prompt: _prompt!),
              ),
              if (_prompt!.focusTaskId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Chip(
                    avatar: const Icon(Icons.flag, size: 16),
                    label: Text(
                      'Foco: #${_prompt!.focusTaskId} ${_prompt!.focusTaskTitle ?? ''}',
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.textSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _prompt!.prompt,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (widget.project.workspacePath.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => OpenInCursorAction.show(
                        context,
                        workspacePath: widget.project.workspacePath,
                        projectTitle: widget.project.title,
                      ),
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Abrir en Cursor'),
                    ),
                  FilledButton.icon(
                    onPressed: _loading || _prompt == null ? null : _copyPrompt,
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('Copiar prompt'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowSteps extends StatelessWidget {
  const _WorkflowSteps({required this.prompt});

  final IdePrompt prompt;

  @override
  Widget build(BuildContext context) {
    final refs = prompt.fileReferences.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flujo recomendado',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '1. TASKBOARD.md exportado al repo\n'
          '2. Abre el workspace en Cursor\n'
          '3. Pega el prompt (referencias: $refs)\n'
          '4. Trabaja en el repo; sync tablero vía MCP taskboard si hace falta',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}
