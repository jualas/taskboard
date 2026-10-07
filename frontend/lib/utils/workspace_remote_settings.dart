/// Host SSH del servidor de workspaces (se configura al arrancar desde
/// assets/data/config.json → workspaceRemote). Vacío = sin enlace Remote SSH.
class WorkspaceRemoteSettings {
  WorkspaceRemoteSettings._();

  static String sshHost = '';
  static String sshUser = '';

  static void apply({String? host, String? user}) {
    if (host != null && host.trim().isNotEmpty) sshHost = host.trim();
    if (user != null && user.trim().isNotEmpty) sshUser = user.trim();
  }
}
