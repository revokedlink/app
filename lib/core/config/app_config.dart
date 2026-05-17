/// Configuration constants for the API connection.
class AppConfig {
  AppConfig._();

  /// Base URL for the PocketBase API.
  /// Change this to your production URL when deploying.
  static const String baseUrl = 'http://127.0.0.1:3000';

  /// PocketBase collection names - mirrors Go backend schema.go
  static const String usersCollection = 'users';
  static const String workspacesCollection = 'workspaces';
  static const String workspaceMembersCollection = 'workspaceMembers';
  static const String recordsCollection = 'records';
  static const String sectionsCollection = 'sections';
  static const String linksCollection = 'links';
  static const String apiKeysCollection = 'apiKeys';
  static const String auditLogsCollection = 'auditLogs';
  static const String templatesCollection = 'templates';
}
