import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/workspace_remote_settings.dart';

/// Abre la carpeta workspace en Cursor (`cursor://file/...`) o copia la ruta.
class OpenInCursor {
  OpenInCursor._();

  /// URI compatible con VS Code / Cursor para abrir carpeta local.
  static String? folderUri(String workspacePath) {
    final trimmed = workspacePath.trim();
    if (trimmed.isEmpty) return null;

    var path = trimmed.replaceAll('\\', '/');
    while (path.contains('//')) {
      path = path.replaceAll('//', '/');
    }

    // Windows: C:/Users/...
    final win = RegExp(r'^[A-Za-z]:/');
    if (win.hasMatch(path)) {
      return 'cursor://file/$path';
    }

    // Unix: quitar barra inicial para cursor://file/mnt/...
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return 'cursor://file/$path';
  }

  /// Variante con doble barra (algunos handlers de VS Code/Cursor).
  static String? folderUriAlt(String workspacePath) {
    final trimmed = workspacePath.trim();
    if (trimmed.isEmpty) return null;
    var path = trimmed.replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    return 'cursor://file$path';
  }

  /// Comando de terminal equivalente (referencia para el usuario).
  static String terminalCommand(String workspacePath) {
    final p = workspacePath.trim();
    if (p.contains(' ')) return 'cursor "$p"';
    return 'cursor $p';
  }

  /// Ruta alternativa habitual en el mini PC (~/datos ↔ /mnt/datos).
  static String? pathHint(String workspacePath) {
    final p = workspacePath.trim();
    if (p.startsWith('/mnt/datos/docker/')) {
      return p.replaceFirst('/mnt/datos/docker', '~/datos/docker');
    }
    if (p.contains('/Proyectos/')) {
      final idx = p.indexOf('/Proyectos/');
      return '~/datos/Proyectos${p.substring(idx + '/Proyectos'.length)}';
    }
    return null;
  }

  static Future<bool> launchFolder(String workspacePath) async {
    final uriStr = folderUri(workspacePath);
    if (uriStr == null) return false;
    final uri = Uri.parse(uriStr);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> launchFolderAlt(String workspacePath) async {
    final uriStr = folderUriAlt(workspacePath);
    if (uriStr == null) return false;
    final uri = Uri.parse(uriStr);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// True si la ruta vive en el mini PC (no en el portátil local).
  static bool isMiniPcPath(String workspacePath) {
    final p = workspacePath.trim();
    return p.startsWith('/mnt/datos/') ||
        p.startsWith('/home/jualas/datos/');
  }

  /// Deep link Cursor Remote SSH (carpeta en el mini PC).
  static String? remoteSshUri(String workspacePath) {
    return remoteSshUriWith(
      workspacePath,
      host: WorkspaceRemoteSettings.sshHost,
      sshUser: WorkspaceRemoteSettings.sshUser,
    );
  }

  static String? remoteSshUriWith(
    String workspacePath, {
    required String host,
    required String sshUser,
  }) {
    if (!isMiniPcPath(workspacePath)) return null;
    if (host.trim().isEmpty || sshUser.trim().isEmpty) return null;
    var path = workspacePath.trim().replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    final remote = Uri.encodeComponent('$sshUser@$host');
    return 'cursor://vscode-remote/ssh-remote+$remote$path';
  }

  static Future<bool> launchRemoteSsh(String workspacePath) async {
    final uriStr = remoteSshUri(workspacePath);
    if (uriStr == null) return false;
    final uri = Uri.parse(uriStr);
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  static Future<void> copyPath(String workspacePath) async {
    await Clipboard.setData(ClipboardData(text: workspacePath.trim()));
  }

  static String remoteSshInstructions(String workspacePath) {
    final host = WorkspaceRemoteSettings.sshHost;
    final sshUser = WorkspaceRemoteSettings.sshUser;
    return 'Estás en el portátil: esta carpeta está en el mini PC ($host).\n\n'
        '1. Cursor → Remote SSH → $sshUser@$host\n'
        '2. File → Open Folder → pega:\n$workspacePath\n\n'
        'Terminal: ssh $sshUser@$host\n'
        'MCP TaskBoard: API http://$host:8101 (ver docs/MCP_TASKBOARD.md)';
  }
}

/// Diálogo / snackbar para abrir workspace en Cursor desde la web.
class OpenInCursorAction {
  static Future<void> show(
    BuildContext context, {
    required String workspacePath,
    String? projectTitle,
  }) async {
    final path = workspacePath.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este proyecto no tiene carpeta workspace. Configúrala en Editar proyecto.',
          ),
        ),
      );
      return;
    }

    // En Flutter Web, cursor:// casi nunca abre la app desde el navegador;
    // mostramos diálogo con ruta copiada para feedback inmediato.
    if (kIsWeb) {
      await _showDialog(context, path: path, projectTitle: projectTitle, autoCopy: true);
      return;
    }

    try {
      final launched = await OpenInCursor.launchFolder(path);
      if (!context.mounted) return;
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              projectTitle != null
                  ? 'Abriendo «$projectTitle» en Cursor…'
                  : 'Abriendo carpeta en Cursor…',
            ),
            action: SnackBarAction(
              label: 'Copiar ruta',
              onPressed: () => OpenInCursor.copyPath(path),
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Continuar al diálogo.
    }

    if (!context.mounted) return;
    await _showDialog(context, path: path, projectTitle: projectTitle);
  }

  static Future<void> _showDialog(
    BuildContext context, {
    required String path,
    String? projectTitle,
    bool autoCopy = false,
  }) async {
    if (autoCopy) {
      await OpenInCursor.copyPath(path);
    }

    if (!context.mounted) return;

    final onMiniPc = OpenInCursor.isMiniPcPath(path);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(onMiniPc ? 'Abrir en Cursor (mini PC)' : 'Abrir en Cursor'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (autoCopy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ruta copiada al portapapeles',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(ctx).colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (onMiniPc) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'La carpeta está en el mini PC (${WorkspaceRemoteSettings.sshHost}), no en tu portátil. '
                    'Usa Remote SSH en Cursor o pega la ruta tras conectar.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (projectTitle != null) ...[
                Text(projectTitle, style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
              ],
              SelectableText(
                path,
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
              if (OpenInCursor.pathHint(path) case final hint?) ...[
                const SizedBox(height: 8),
                Text(
                  'En el mini PC también: $hint',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                onMiniPc
                    ? OpenInCursor.remoteSshInstructions(path)
                    : (kIsWeb
                        ? 'Pega la ruta en Cursor → File → Open Folder (Ctrl+V).'
                        : 'File → Open Folder en Cursor, o: ${OpenInCursor.terminalCommand(path)}'),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await OpenInCursor.copyPath(path);
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ruta copiada')),
                );
              }
            },
            child: const Text('Copiar ruta'),
          ),
          if (onMiniPc)
            FilledButton(
              onPressed: () async {
                var ok = false;
                try {
                  ok = await OpenInCursor.launchRemoteSsh(path);
                } catch (_) {}
                if (!ctx.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Usa Cursor → Remote SSH → ${WorkspaceRemoteSettings.sshUser}@${WorkspaceRemoteSettings.sshHost} y luego Open Folder con la ruta copiada.',
                      ),
                      duration: const Duration(seconds: 6),
                    ),
                  );
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Remote SSH'),
            )
          else
            FilledButton(
              onPressed: () async {
                var ok = false;
                try {
                  ok = await OpenInCursor.launchFolder(path);
                  if (!ok) ok = await OpenInCursor.launchFolderAlt(path);
                } catch (_) {}
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usa Copiar ruta y Open Folder en Cursor.'),
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: const Text('Intentar abrir'),
            ),
        ],
      ),
    );
  }
}

/// Icono de barra de herramientas (Kanban / lista).
class OpenInCursorIconButton extends StatelessWidget {
  const OpenInCursorIconButton({
    super.key,
    required this.workspacePath,
    this.projectTitle,
  });

  final String workspacePath;
  final String? projectTitle;

  @override
  Widget build(BuildContext context) {
    if (workspacePath.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.terminal),
      tooltip: OpenInCursor.isMiniPcPath(workspacePath)
          ? 'Abrir carpeta en Cursor (Remote SSH al mini PC)'
          : 'Abrir carpeta en Cursor',
      onPressed: () => OpenInCursorAction.show(
        context,
        workspacePath: workspacePath,
        projectTitle: projectTitle,
      ),
    );
  }
}

/// Resuelve workspace desde [ProjectsBloc] por id de proyecto.
class OpenInCursorProjectButton extends StatelessWidget {
  const OpenInCursorProjectButton({
    super.key,
    required this.projectId,
    this.projectTitle,
    this.workspacePath,
  });

  final int projectId;
  final String? projectTitle;
  final String? workspacePath;

  @override
  Widget build(BuildContext context) {
    final path = workspacePath?.trim() ?? '';
    if (path.isNotEmpty) {
      return OpenInCursorIconButton(
        workspacePath: path,
        projectTitle: projectTitle,
      );
    }
    return const SizedBox.shrink();
  }
}
