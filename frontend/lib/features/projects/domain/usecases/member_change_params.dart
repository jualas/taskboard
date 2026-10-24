import '../entities/project_member.dart';

class MemberChangeParams {
  const MemberChangeParams({
    required this.projectId,
    required this.userId,
    required this.role,
  });
  final int projectId;
  final String userId;
  final ProjectMemberRole role;
}
