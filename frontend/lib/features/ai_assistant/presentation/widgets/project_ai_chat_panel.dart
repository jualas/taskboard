import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/ui/root_scaffold_messenger.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../domain/entities/ai_task_suggestion.dart';
import '../../domain/usecases/create_project_from_ai_plan.dart';
import '../bloc/project_ai_chat_cubit.dart';

export '../bloc/project_ai_chat_cubit.dart' show ProjectAiChatMode;

enum _AssistantMode { plan, agent }

/// Panel de chat con IA para planificar tareas de un proyecto (creación o existente).
class ProjectAiChatPanel extends StatelessWidget {
  const ProjectAiChatPanel({
    super.key,
    required this.mode,
    required this.projectTitle,
    required this.projectDescription,
    this.projectId,
    this.existingTasks = const [],
    this.onDraftTasksChanged,
    this.onTasksApplied,
    this.onProjectCreated,
  });

  final ProjectAiChatMode mode;
  final String projectTitle;
  final String projectDescription;
  final int? projectId;
  final List<Task> existingTasks;
  final ValueChanged<List<AiTaskSuggestion>>? onDraftTasksChanged;
  final VoidCallback? onTasksApplied;

  /// Modo nuevo proyecto: se llama tras crear el proyecto con el borrador.
  final ValueChanged<ProjectFromAiPlan>? onProjectCreated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProjectAiChatCubit>()
        ..start(
          mode: mode,
          projectTitle: projectTitle,
          projectDescription: projectDescription,
          projectId: projectId,
          existingTasks: existingTasks,
        ),
      child: _ProjectAiChatView(
        mode: mode,
        projectId: projectId,
        onDraftTasksChanged: onDraftTasksChanged,
        onTasksApplied: onTasksApplied,
        onProjectCreated: onProjectCreated,
      ),
    );
  }
}

class _ProjectAiChatView extends StatefulWidget {
  const _ProjectAiChatView({
    required this.mode,
    required this.projectId,
    required this.onDraftTasksChanged,
    required this.onTasksApplied,
    required this.onProjectCreated,
  });

  final ProjectAiChatMode mode;
  final int? projectId;
  final ValueChanged<List<AiTaskSuggestion>>? onDraftTasksChanged;
  final VoidCallback? onTasksApplied;
  final ValueChanged<ProjectFromAiPlan>? onProjectCreated;

  @override
  State<_ProjectAiChatView> createState() => _ProjectAiChatViewState();
}

class _ProjectAiChatViewState extends State<_ProjectAiChatView> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  bool _draftExpanded = true;
  _AssistantMode _assistantMode = _AssistantMode.plan;
  bool _agentExecute = false;
  bool _historyExpanded = false;

  ProjectAiChatCubit get _cubit => context.read<ProjectAiChatCubit>();
  ProjectAiChatState get _chat => _cubit.state;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startNewAgentSession() async {
    if (widget.projectId == null) return;
    final result = await _cubit.resetAgentSession();
    if (!mounted) return;
    final failure = result.failureOrNull;
    if (failure != null) {
      kRootScaffoldMessenger.currentState?.showSnackBar(
        SnackBar(content: Text('No se pudo reiniciar la sesión: ${failure.message}')),
      );
      return;
    }
    kRootScaffoldMessenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          'Sesión agent reiniciada. El próximo prompt creará una conversación nueva.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _reuseAgentPrompt(String prompt) {
    _inputController.text = prompt;
    _inputController.selection = TextSelection.collapsed(offset: prompt.length);
  }

  String _formatRunTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $h:$m';
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _chat.isLoading) return;
    _inputController.clear();

    if (_assistantMode == _AssistantMode.agent) {
      await _cubit.sendAgentMessage(text, execute: _agentExecute);
      return;
    }

    kRootScaffoldMessenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          'Consultando IA… en peticiones de alineación puede tardar 2–5 min.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
    await _cubit.sendPlanMessage(text);
  }

  Future<void> _applyNewTasks() async {
    if (widget.mode != ProjectAiChatMode.existing) return;
    if (widget.projectId == null || _chat.isApplying) return;

    if (_chat.newDraftTasks.isEmpty) {
      kRootScaffoldMessenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No hay tareas nuevas en el borrador para aplicar.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final result = await _cubit.applyNewTasks();
    if (!mounted) return;
    result.when(
      success: (count) {
        widget.onTasksApplied?.call();
        kRootScaffoldMessenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? '1 tarea nueva creada en el proyecto.'
                  : '$count tareas nuevas creadas en el proyecto.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      },
      onFailure: (failure) {
        kRootScaffoldMessenger.currentState?.showSnackBar(
          SnackBar(
            content: Text('No se pudieron crear las tareas: ${failure.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  Future<void> _createProject() async {
    if (widget.mode != ProjectAiChatMode.create || _chat.isApplying) return;
    final result = await _cubit.createProjectFromDraft();
    if (!mounted) return;
    result.when(
      success: (created) {
        final taskFailure = created.taskFailure;
        kRootScaffoldMessenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              taskFailure != null
                  ? 'Proyecto creado, pero no se pudieron crear todas las tareas: '
                        '${taskFailure.message}'
                  : created.createdTasks == 1
                  ? 'Proyecto creado con 1 tarea.'
                  : 'Proyecto creado con ${created.createdTasks} tareas.',
            ),
            backgroundColor: taskFailure != null
                ? AppColors.warning
                : AppColors.success,
          ),
        );
        widget.onProjectCreated?.call(created);
      },
      onFailure: (failure) {
        kRootScaffoldMessenger.currentState?.showSnackBar(
          SnackBar(
            content: Text('No se pudo crear el proyecto: ${failure.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProjectAiChatCubit, ProjectAiChatState>(
      listenWhen: (prev, next) => prev.draftTasks != next.draftTasks,
      listener: (context, state) => widget.onDraftTasksChanged
          ?.call(List<AiTaskSuggestion>.from(state.draftTasks)),
      child: BlocConsumer<ProjectAiChatCubit, ProjectAiChatState>(
        listenWhen: (prev, next) =>
            prev.entries != next.entries || prev.isLoading != next.isLoading,
        listener: (context, state) => _scrollToBottom(),
        builder: (context, state) => _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final newCount = _chat.newDraftTasks.length;
    final modeLabel = widget.mode == ProjectAiChatMode.existing
        ? 'Proyecto existente'
        : 'Nuevo proyecto';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accentPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asistente IA',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      modeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_chat.providerLabel != null)
                Chip(
                  label: Text(_chat.providerLabel!),
                  backgroundColor:
                      AppColors.accentSecondary.withValues(alpha: 0.15),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.accentPrimary,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ),
        // Agent necesita la carpeta de un proyecto ya creado.
        if (widget.mode == ProjectAiChatMode.existing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<_AssistantMode>(
              segments: const [
                ButtonSegment(
                  value: _AssistantMode.plan,
                  label: Text('Planificar'),
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                ),
                ButtonSegment(
                  value: _AssistantMode.agent,
                  label: Text('Agent (CLI)'),
                  icon: Icon(Icons.terminal, size: 18),
                ),
              ],
              selected: {_assistantMode},
              onSelectionChanged: _chat.isLoading
                  ? null
                  : (s) {
                      final mode = s.first;
                      setState(() => _assistantMode = mode);
                      if (mode == _AssistantMode.agent) {
                        _cubit.loadAgentMeta();
                      }
                    },
            ),
          ),
        if (_assistantMode == _AssistantMode.agent) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Ejecuta el CLI Cursor Agent en la carpeta workspace del proyecto. '
              'La salida aparece en vivo abajo (como un terminal).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (widget.projectId != null) _buildAgentSessionBar(theme),
        ],
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _chat.entries.length + (_chat.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _chat.entries.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return _buildMessageBubble(_chat.entries[index]);
            },
          ),
        ),
        if (_chat.draftTasks.isNotEmpty) _buildDraftSection(newCount),
        _buildInputBar(theme),
      ],
    );
  }

  Widget _buildAgentSessionBar(ThemeData theme) {
    final sessionLabel = _chat.agentSession != null
        ? 'Sesión ${_chat.agentSession!.shortId}…'
        : 'Sin sesión guardada';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.link, size: 16),
                label: Text(sessionLabel),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              FilterChip(
                label: const Text('Continuar sesión'),
                selected: _chat.continueSession,
                onSelected: _chat.isLoading
                    ? null
                    : (v) => _cubit.setContinueSession(v),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              ActionChip(
                avatar: const Icon(Icons.refresh, size: 16),
                label: const Text('Nueva sesión'),
                onPressed: _chat.isLoading ? null : _startNewAgentSession,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (_chat.agentRuns.isNotEmpty)
            Material(
              color: AppColors.backgroundSecondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () =>
                        setState(() => _historyExpanded = !_historyExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _historyExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Historial (${_chat.agentRuns.length})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_historyExpanded)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: _chat.agentRuns.length,
                        itemBuilder: (context, index) {
                          final run = _chat.agentRuns[index];
                          final prompt = run.prompt.trim();
                          final preview = prompt.length > 72
                              ? '${prompt.substring(0, 72)}…'
                              : prompt;
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            leading: Icon(
                              run.isError
                                  ? Icons.error_outline
                                  : run.executeMode
                                      ? Icons.edit
                                      : Icons.visibility,
                              size: 18,
                              color: run.isError
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                            title: Text(
                              preview.isEmpty ? '(sin prompt)' : preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            subtitle: Text(
                              _formatRunTime(run.createdAt),
                              style: const TextStyle(fontSize: 10),
                            ),
                            onTap: prompt.isEmpty
                                ? null
                                : () => _reuseAgentPrompt(prompt),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatEntry message) {
    if (message.isTerminal) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: message.isStreaming
                  ? AppColors.accentPrimary.withValues(alpha: 0.5)
                  : AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.terminal,
                    size: 14,
                    color: message.isStreaming
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message.isStreaming ? 'agent — ejecutando…' : 'agent',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                message.content.isEmpty && message.isStreaming
                    ? '…'
                    : message.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFFE8E8E8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isUser = message.isUser;
    final bg = isUser
        ? AppColors.accentPrimary.withValues(alpha: 0.12)
        : AppColors.backgroundSecondary;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isUser ? 12 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 12),
              ),
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSection(int newCount) {
    return Material(
      color: AppColors.backgroundSecondary.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _draftExpanded = !_draftExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _draftExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Borrador: ${_chat.draftTasks.length} tarea(s)'
                      '${newCount > 0 ? ' · $newCount nueva(s)' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_draftExpanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: _chat.draftTasks.length,
                itemBuilder: (context, index) {
                  final task = _chat.draftTasks[index];
                  final isNew = _chat.newDraftTasks.any(
                    (t) =>
                        t.title.trim().toLowerCase() ==
                        task.title.trim().toLowerCase(),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isNew ? Icons.fiber_new : Icons.task_alt,
                          size: 16,
                          color: isNew
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isNew
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                              if (task.subtasks.isNotEmpty)
                                Text(
                                  '${task.subtasks.length} ítems checklist · ${task.complexity.displayName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (widget.mode == ProjectAiChatMode.existing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FilledButton.icon(
                onPressed: (_chat.isApplying || newCount == 0) ? null : _applyNewTasks,
                icon: _chat.isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnDark,
                        ),
                      )
                    : const Icon(Icons.playlist_add),
                label: Text(
                  newCount == 0
                      ? 'Sin tareas nuevas para aplicar'
                      : newCount == 1
                          ? 'Aplicar 1 tarea nueva'
                          : 'Aplicar $newCount tareas nuevas',
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FilledButton.icon(
                onPressed: _chat.isApplying ? null : _createProject,
                icon: _chat.isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnDark,
                        ),
                      )
                    : const Icon(Icons.create_new_folder_outlined),
                label: Text(
                  _chat.draftTasks.length == 1
                      ? 'Crear proyecto con 1 tarea'
                      : 'Crear proyecto con ${_chat.draftTasks.length} tareas',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    final isAgent = _assistantMode == _AssistantMode.agent;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAgent)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Permitir editar archivos en el repo (--force)',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Desactivado: solo lectura (modo ask). Activado: puede modificar código y docs.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _agentExecute,
                onChanged: _chat.isLoading
                    ? null
                    : (v) => setState(() => _agentExecute = v ?? false),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: isAgent
                          ? 'Instrucción para agent (p. ej. alinear STATUS.md y el tablero)…'
                          : widget.mode == ProjectAiChatMode.create
                              ? 'Describe el proyecto o pide cambios…'
                              : 'Pide más tareas, prioridades o ajustes…',
                      filled: true,
                      fillColor: AppColors.backgroundPrimary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.25),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _chat.isLoading ? null : _sendMessage,
                  tooltip: isAgent ? 'Ejecutar agent' : 'Enviar',
                  icon: Icon(isAgent ? Icons.play_arrow : Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
