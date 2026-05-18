/// Configuration constants for the API connection.
class AppConfig {
  AppConfig._();

  /// Base URL for the PocketBase API.
  /// Change this to your production URL when deploying.
  static const String baseUrl = 'http://127.0.0.1:3000';

  /// PocketBase collection names - mirrors Go backend `util/schema.go`.
  static const String usersCollection = 'users';
  static const String workspacesCollection = 'workspaces';
  static const String workspaceMembersCollection = 'workspaceMembers';
  static const String recordsCollection = 'records';
  static const String sectionsCollection = 'sections';
  static const String linksCollection = 'links';
  static const String apiKeysCollection = 'apiKeys';
  static const String auditLogsCollection = 'auditLogs';
  static const String templatesCollection = 'templates';
  static const String identitiesCollection = 'identities';
  static const String requestsCollection = 'requests';
  static const String requestResponsesCollection = 'requestResponses';
  static const String notificationsCollection = 'notifications';
  static const String handshakesCollection = 'handshakes';

  /// @deprecated kept for backwards-compat with old request-flow screens
  /// that still reference the previous "connections" collection. The new
  /// model is `requestResponses` (+ `handshakes`).
  static const String connectionsCollection = 'connections';
}
