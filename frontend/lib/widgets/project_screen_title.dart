import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/projects_bloc.dart';
import '../themes/app_theme.dart';

/// Título de AppBar con nombre del proyecto y etiqueta de la vista (Kanban, lista…).
class ProjectScreenTitle extends StatefulWidget {
  const ProjectScreenTitle({
    super.key,
    required this.projectId,
    required this.viewLabel,
  });

  final int projectId;
  final String viewLabel;

  @override
  State<ProjectScreenTitle> createState() => _ProjectScreenTitleState();
}

class _ProjectScreenTitleState extends State<ProjectScreenTitle> {
  String? _projectTitle;

  @override
  void initState() {
    super.initState();
    _resolveTitle();
  }

  @override
  void didUpdateWidget(ProjectScreenTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _resolveTitle();
    }
  }

  void _resolveTitle() {
    final bloc = context.read<ProjectsBloc>();
    final cached = _titleFromState(bloc.state);
    if (cached != null) {
      setState(() => _projectTitle = cached);
      return;
    }

    if (bloc.state is! ProjectsLoaded && bloc.state is! ProjectsLoading) {
      bloc.add(ProjectsLoadRequested());
    }

    bloc.projectsService.getProject(widget.projectId).then((project) {
      if (mounted && project != null) {
        setState(() => _projectTitle = project.title);
      }
    });
  }

  String? _titleFromState(ProjectsState state) {
    if (state is! ProjectsLoaded) return null;
    for (final p in state.projects) {
      if (p.id == widget.projectId) return p.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProjectsBloc, ProjectsState>(
      listener: (context, state) {
        final title = _titleFromState(state);
        if (title != null && title != _projectTitle) {
          setState(() => _projectTitle = title);
        }
      },
      child: _buildTitle(context),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    const onDark = AppColors.textOnDark;

    if (_projectTitle == null || _projectTitle!.trim().isEmpty) {
      return Text(
        widget.viewLabel,
        style: theme.appBarTheme.titleTextStyle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _projectTitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: onDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          widget.viewLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: onDark.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
