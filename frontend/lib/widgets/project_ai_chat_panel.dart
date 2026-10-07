import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/ai_assistant_service.dart';
import '../services/tasks_service.dart';
import '../themes/app_theme.dart';
import '../ui/root_scaffold_messenger.dart';
import '../utils/ai_task_conversion.dart';

enum ProjectAiChatMode { create, existing }

enum _AssistantMode { plan, agent }

/// Panel de chat con IA para planificar tareas de un proyecto (creación o existente).
class ProjectAiChatPanel extends StatefulWidget {
  const ProjectAiChatPanel({
    super.key,
    required this.mode,
    required this.projectTitle,
    required this.projectDescription,
    this.projectId,
    this.existingTasks = const [],
    this.tasksService,
    this.onDraftTasksChanged,
    this.onTasksApplied,
  });

  final ProjectAiChatMode mode;
  final String projectTitle;
  final String projectDescription;
  final int? projectId;
  final List<Task> existingTasks;
  final TasksService? tasksService;
  final ValueChanged<List<AiTaskSuggestion>>? onDraftTasksChanged;
  final VoidCallback? onTasksApplied;

  @override
  State<ProjectAiChatPanel> createState() => _ProjectAiChatPanelState();
}

class _DisplayMessage {
  const _DisplayMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  final String role;
  final String content;
  final bool isStreaming;

  bool get isUser => role == 'user';
  bool get isTerminal => role == 'terminal';
}

class _ProjectAiChatPanelState extends State<ProjectAiChatPanel> {
  final _ai = AiAssistantService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_DisplayMessage> _displayMessages = [];
  final List<AiChatMessage> _apiMessages = [];
  List<AiTaskSuggestion> _baseline = [];
  List<AiTaskSuggestion> _draftTasks = [];
  bool _isLoading = false;
  bool _isApplying = false;
  String? _providerLabel;
  bool _draftExpanded = true;
  _AssistantMode _assistantMode = _AssistantMode.plan;
  bool _agentExecute = false;
  bool _continueSession = true;
  bool _forceNewSession = false;
  bool _historyExpanded = false;
  AgentSession? _agentSession;
  List<AgentRun> _agentRuns = [];
  final List<String> _agentLogLines = [];
  String _agentStreamText = '';

  @override
  void initState() {
    super.initState();
    _baseline = aiSuggestionsFromTasks(widget.existingTasks);
    _draftTasks = List<AiTaskSuggestion>.from(_baseline);

    if (widget.mode == ProjectAiChatMode.existing) {
      _displayMessages.add(
        const _DisplayMessage(
          role: 'assistant',
          content:
              'Puedo ayudarte a ampliar o refinar el plan de tareas del proyecto. '
              'Describe qué necesitas y revisaré el borrador antes de crear tareas nuevas.',
        ),
      );
    } else {
      _displayMessages.add(
        const _DisplayMessage(
          role: 'assistant',
          content:
              'Describe el proyecto o el alcance inicial y generaré un plan de tareas. '
              'Luego podrás pedir cambios en el chat.',
        ),
      );
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _notifyDraftChanged() {
    widget.onDraftTasksChanged?.call(List<AiTaskSuggestion>.from(_draftTasks));
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

  Future<void> _loadAgentMeta() async {
    final projectId = widget.projectId;
    if (projectId == null) return;
    try {
      final session = await _ai.getAgentSession(projectId);
      final runs = await _ai.getAgentRuns(projectId);
      if (!mounted) return;
      setState(() {
        _agentSession = session;
        _agentRuns = runs;
      });
    } catch (_) {
      // Historial opcional; no bloquear el panel.
    }
  }

  Future<void> _startNewAgentSession() async {
    final projectId = widget.projectId;
    if (projectId == null) return;
    try {
      await _ai.resetAgentSession(projectId);
      if (!mounted) return;
      setState(() {
        _agentSession = null;
        _continueSession = false;
        _forceNewSession = true;
      });
      kRootScaffoldMessenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Sesión agent reiniciada. El próximo prompt creará una conversación nueva.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      kRootScaffoldMessenger.currentState?.showSnackBar(
        SnackBar(content: Text('No se pudo reiniciar la sesión: $e')),
      );
    }
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

  void _mergeAgentStreamText(String piece) {
    if (piece.isEmpty) return;
    if (_agentStreamText.isEmpty) {
      _agentStreamText = piece;
      return;
    }
    if (piece.startsWith(_agentStreamText)) {
      _agentStreamText = piece;
      return;
    }
    if (_agentStreamText.startsWith(piece)) return;
    _agentStreamText += piece;
  }

  String _terminalDisplayText() {
    final parts = <String>[..._agentLogLines];
    if (_agentStreamText.isNotEmpty) {
      parts.add(_agentStreamText);
    }
    return parts.join('\n');
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_assistantMode == _AssistantMode.agent) {
      await _sendAgentMessage(text);
      return;
    }

    setState(() {
      _isLoading = true;
      _inputController.clear();
      _displayMessages.add(_DisplayMessage(role: 'user', content: text));
      _apiMessages.add(AiChatMessage(role: 'user', content: text));
    });
    _scrollToBottom();

    kRootScaffoldMessenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          _assistantMode == _AssistantMode.plan
              ? 'Consultando IA… en peticiones de alineación puede tardar 2–5 min.'
              : 'Consultando Cursor Agent… puede tardar varios minutos si analiza el repo.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );

    try {
      if (widget.mode == ProjectAiChatMode.create &&
          _draftTasks.isEmpty &&
          _apiMessages.where((m) => m.role == 'user').length == 1) {
        final suggestResult = await _ai.suggestProjectPlan(
          projectTitle: widget.projectTitle,
          projectDescription: widget.projectDescription,
          userMessage: text,
        );
        final tasks = suggestResult.suggestions;
        final assistantText = tasks.isEmpty
            ? 'No pude generar tareas útiles. Prueba a ser más concreto sobre objetivos y entregables.'
            : 'Plan inicial con ${tasks.length} tarea(s). Revisa el borrador abajo y pide ajustes si hace falta.';

        if (!mounted) return;
        setState(() {
          _draftTasks = tasks;
          _providerLabel = suggestResult.providerLabel;
          _displayMessages.add(
            _DisplayMessage(role: 'assistant', content: assistantText),
          );
          _apiMessages.add(
            AiChatMessage(role: 'assistant', content: assistantText),
          );
        });
        _notifyDraftChanged();
      } else {
        final result = await _ai.chatProjectPlan(
          projectTitle: widget.projectTitle,
          projectDescription: widget.projectDescription,
          messages: _apiMessages,
          draftTasks: _draftTasks,
          projectId: widget.projectId,
        );

        if (!mounted) return;
        setState(() {
          _displayMessages.add(
            _DisplayMessage(role: 'assistant', content: result.message),
          );
          _apiMessages.add(
            AiChatMessage(role: 'assistant', content: result.message),
          );
          if (result.tasks != null) {
            _draftTasks = result.tasks!;
            _notifyDraftChanged();
          }
          _providerLabel = result.providerLabel;
        });
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final errorText = AiAssistantService.describeErrorForUser(e);
      setState(() {
        _displayMessages.add(
          _DisplayMessage(role: 'assistant', content: errorText),
        );
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendAgentMessage(String text) async {
    setState(() {
      _isLoading = true;
      _inputController.clear();
      _agentLogLines.clear();
      _agentStreamText = '';
      _displayMessages.add(_DisplayMessage(role: 'user', content: text));
      _displayMessages.add(
        const _DisplayMessage(role: 'terminal', content: '', isStreaming: true),
      );
      _providerLabel = 'Cursor Agent';
    });
    _scrollToBottom();

    final terminalIndex = _displayMessages.length - 1;

    try {
      await for (final event in _ai.streamAgentRun(
        prompt: text,
        projectId: widget.projectId,
        projectTitle: widget.projectTitle,
        projectDescription: widget.projectDescription,
        execute: _agentExecute,
        continueSession: _continueSession,
        newSession: _forceNewSession,
      )) {
        if (!mounted) return;
        switch (event.kind) {
          case 'init':
          case 'tool':
          case 'meta':
          case 'log':
            if (event.text.isNotEmpty) {
              _agentLogLines.add(event.text);
            }
            break;
          case 'session':
            if (event.text.isNotEmpty) {
              _agentLogLines.add(event.text);
            }
            if (event.sessionId != null && event.sessionId!.isNotEmpty) {
              _agentSession = AgentSession(
                projectId: widget.projectId ?? 0,
                sessionId: event.sessionId!,
                updatedAt: DateTime.now().toUtc(),
              );
            }
            break;
          case 'text':
            _mergeAgentStreamText(event.text);
            break;
          case 'done':
            if (event.text.isNotEmpty) {
              _agentStreamText = event.text;
            }
            if (event.sessionId != null && event.sessionId!.isNotEmpty) {
              _agentSession = AgentSession(
                projectId: widget.projectId ?? 0,
                sessionId: event.sessionId!,
                updatedAt: DateTime.now().toUtc(),
              );
            }
            break;
          case 'error':
            _agentLogLines.add('✗ ${event.text}');
            break;
        }
        setState(() {
          _displayMessages[terminalIndex] = _DisplayMessage(
            role: 'terminal',
            content: _terminalDisplayText(),
            isStreaming: true,
          );
        });
        _scrollToBottom();
      }

      if (!mounted) return;
      setState(() {
        _displayMessages[terminalIndex] = _DisplayMessage(
          role: 'terminal',
          content: _terminalDisplayText().isEmpty
              ? '(sin salida del agente)'
              : _terminalDisplayText(),
          isStreaming: false,
        );
      });
    } catch (e) {
      if (!mounted) return;
      final errorText = AiAssistantService.describeErrorForUser(e);
      setState(() {
        _displayMessages[terminalIndex] = _DisplayMessage(
          role: 'terminal',
          content: '✗ $errorText',
          isStreaming: false,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _forceNewSession = false;
          if (_agentSession != null) {
            _continueSession = true;
          }
        });
        await _loadAgentMeta();
      }
      _scrollToBottom();
    }
  }

  Future<void> _applyNewTasks() async {
    if (widget.mode != ProjectAiChatMode.existing) return;
    final projectId = widget.projectId;
    final tasksService = widget.tasksService;
    if (projectId == null || tasksService == null || _isApplying) return;

    final pending = newTasksInDraft(draft: _draftTasks, baseline: _baseline);
    if (pending.isEmpty) {
      kRootScaffoldMessenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No hay tareas nuevas en el borrador para aplicar.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isApplying = true);
    try {
      final count = await applyNewAiTasksToProject(
        tasksService: tasksService,
        projectId: projectId,
        draft: _draftTasks,
        baseline: _baseline,
      );
      if (!mounted) return;
      setState(() {
        _baseline = List<AiTaskSuggestion>.from(_draftTasks);
      });
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
    } catch (e) {
      if (!mounted) return;
      kRootScaffoldMessenger.currentState?.showSnackBar(
        SnackBar(
          content: Text('No se pudieron crear las tareas: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  List<AiTaskSuggestion> get _newDraftTasks =>
      newTasksInDraft(draft: _draftTasks, baseline: _baseline);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final newCount = _newDraftTasks.length;
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
              if (_providerLabel != null)
                Chip(
                  label: Text(_providerLabel!),
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
            onSelectionChanged: _isLoading
                ? null
                : (s) {
                    final mode = s.first;
                    setState(() => _assistantMode = mode);
                    if (mode == _AssistantMode.agent) {
                      _loadAgentMeta();
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
            itemCount: _displayMessages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _displayMessages.length) {
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
              return _buildMessageBubble(_displayMessages[index]);
            },
          ),
        ),
        if (_draftTasks.isNotEmpty) _buildDraftSection(newCount),
        _buildInputBar(theme),
      ],
    );
  }

  Widget _buildAgentSessionBar(ThemeData theme) {
    final sessionLabel = _agentSession != null
        ? 'Sesión ${_agentSession!.shortId}…'
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
                selected: _continueSession,
                onSelected: _isLoading
                    ? null
                    : (v) => setState(() => _continueSession = v),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              ActionChip(
                avatar: const Icon(Icons.refresh, size: 16),
                label: const Text('Nueva sesión'),
                onPressed: _isLoading ? null : _startNewAgentSession,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (_agentRuns.isNotEmpty)
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
                            'Historial (${_agentRuns.length})',
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
                        itemCount: _agentRuns.length,
                        itemBuilder: (context, index) {
                          final run = _agentRuns[index];
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

  Widget _buildMessageBubble(_DisplayMessage message) {
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
                      'Borrador: ${_draftTasks.length} tarea(s)'
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
                itemCount: _draftTasks.length,
                itemBuilder: (context, index) {
                  final task = _draftTasks[index];
                  final isNew = _newDraftTasks.any(
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
                onPressed: (_isApplying || newCount == 0) ? null : _applyNewTasks,
                icon: _isApplying
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
                onChanged: _isLoading
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
                  onPressed: _isLoading ? null : _sendMessage,
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
