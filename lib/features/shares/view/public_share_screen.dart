import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_errors.dart';
import '../../../core/services/handshake_service.dart';
import '../../../core/widgets/app_toast.dart';

/// Public link viewer.
///
/// The viewer flow uses the dedicated `/api/public/links/:slug` endpoints
/// (see `cmd/revoked/routes/publicLinks.go`):
///   1. GET → probe. Returns the visible label and which gates apply
///      (password, handshake, expiry).
///   2. POST → submission. Sends password + identity + handshake token,
///      receives the sanitized section/record payload back.
///
/// First-visit handshakes return an `X-Handshake-Token` header; we persist
/// it per slug so return visits can re-authenticate transparently.
class PublicShareScreen extends StatefulWidget {
  final String shareSlug;

  const PublicShareScreen({super.key, required this.shareSlug});

  @override
  State<PublicShareScreen> createState() => _PublicShareScreenState();
}

class _PublicShareScreenState extends State<PublicShareScreen> {
  bool _isLoading = true;
  bool _isUnlocking = false;

  /// Probe result.
  Map<String, dynamic>? _probe;

  /// Successful submission result with records/sections.
  Map<String, dynamic>? _data;

  /// Terminal failure state — wrong slug, revoked, expired, max views hit.
  AppErrorMessage? _terminalError;

  final _passwordCtrl = TextEditingController();
  String? _passwordHint;
  String? _identityIdInput;

  @override
  void initState() {
    super.initState();
    _probeLink();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _handshakeKey() => 'handshake_link_${widget.shareSlug}';

  Future<String?> _loadStoredHandshake() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_handshakeKey());
  }

  Future<void> _persistHandshake(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_handshakeKey(), token);
  }

  Future<void> _probeLink() async {
    setState(() {
      _isLoading = true;
      _terminalError = null;
    });

    try {
      _probe = await ServiceLocator.sharesRepository.getPublicLinkProbe(
        widget.shareSlug,
      );
      // If neither password nor handshake is required, auto-submit so the
      // payload loads immediately (no extra tap for the viewer).
      final requiresPassword = _probe!['requiresPassword'] as bool? ?? false;
      final requireHandshake = _probe!['requireHandshake'] as bool? ?? false;
      if (!requiresPassword && !requireHandshake) {
        await _unlock();
        return;
      }
      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      final msg = AppErrorMessage.fromException(e);
      setState(() {
        _terminalError = msg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _terminalError = AppErrorMessage.fromException(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _unlock() async {
    setState(() {
      _isUnlocking = true;
      _passwordHint = null;
    });

    try {
      final handshake = await _loadStoredHandshake();
      // First contact (no stored token yet) needs a freshly signed
      // challenge so the server can prove the responder controls the
      // identity's private key before issuing a persistent token.
      SignedChallenge? challenge;
      final requireHandshake = _probe?['requireHandshake'] as bool? ?? false;
      if (requireHandshake &&
          handshake == null &&
          _identityIdInput != null &&
          _identityIdInput!.isNotEmpty) {
        challenge = await ServiceLocator.handshakeService.prepare(
          scope: HandshakeService.scopeLink,
          slug: widget.shareSlug,
          identityId: _identityIdInput!,
        );
      }

      final response = await ServiceLocator.sharesRepository.submitPublicLink(
        widget.shareSlug,
        password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
        handshakeToken: handshake,
        identityId: _identityIdInput,
        challengeNonce: challenge?.nonce,
        challengeSignature: challenge?.signature,
      );

      final newHandshake = response.headers['x-handshake-token'];
      if (newHandshake != null && newHandshake.isNotEmpty) {
        await _persistHandshake(newHandshake);
      }

      setState(() {
        _data = response.body as Map<String, dynamic>;
        _isUnlocking = false;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      final msg = AppErrorMessage.fromException(e);
      setState(() {
        if (msg.isTerminal) {
          _terminalError = msg;
        } else {
          _passwordHint = msg.description;
        }
        _isUnlocking = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _passwordHint = e.toString();
        _isUnlocking = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.border),
                ),
              ),
              child: Row(
                children: [
                  Text('Revoked').semiBold.h3,
                  const Spacer(),
                  const OutlineBadge(child: Text('PUBLIC VIEW')),
                ],
              ),
            ),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(size: 24),
            const SizedBox(height: 12),
            Text('Retrieving shared vault…').muted,
          ],
        ),
      );
    }

    if (_terminalError != null) {
      return _buildTerminal(theme, _terminalError!);
    }

    if (_data != null) {
      return _buildContent(theme, _data!);
    }

    // Probe succeeded but gating remains.
    if (_probe != null) {
      final requiresPassword = _probe!['requiresPassword'] as bool? ?? false;
      return _buildPasswordGate(theme, requiresPassword);
    }

    return const SizedBox.shrink();
  }

  Widget _buildTerminal(ThemeData theme, AppErrorMessage msg) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  BootstrapIcons.exclamationOctagon,
                  color: theme.colorScheme.destructive,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(msg.title).h4.semiBold,
                const SizedBox(height: 8),
                Text(
                  msg.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ).small,
                const SizedBox(height: 20),
                OutlineButton(
                  onPressed: _probeLink,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordGate(ThemeData theme, bool requiresPassword) {
    final label = _probe?['label'] as String? ?? 'Protected share';

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      BootstrapIcons.shieldLock,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label).h4.semiBold),
                  ],
                ),
                const SizedBox(height: 12),
                if (requiresPassword) ...[
                  const Text(
                    'This share is password-protected. Enter the password the sender provided to view its contents.',
                  ).muted.small,
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    placeholder: const Text('Password'),
                    onSubmitted: (_) => _unlock(),
                  ),
                  if (_passwordHint != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _passwordHint!,
                      style: TextStyle(color: theme.colorScheme.destructive),
                    ).xSmall,
                  ],
                ] else ...[
                  const Text(
                    'This share is bound to a cryptographic identity. Tap unlock to continue.',
                  ).muted.small,
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  onPressed: _isUnlocking ? null : _unlock,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isUnlocking) ...[
                        const CircularProgressIndicator(
                          size: 14,
                          strokeWidth: 2,
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Text('Unlock'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, Map<String, dynamic> data) {
    final label = data['label'] as String? ?? 'Shared Items';
    final sections = (data['sections'] as List<dynamic>?) ?? [];
    final records = (data['records'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          BootstrapIcons.share,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(label).h3.semiBold),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A read-only secure view of shared items from a Revoked vault.',
                      style: TextStyle(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ).small,
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (records.isNotEmpty) ...[
                const Text('Shared Records').h4.semiBold,
                const SizedBox(height: 10),
                ...records.map(
                  (r) => _PublicRecordCard(record: r as Map<String, dynamic>),
                ),
                const SizedBox(height: 24),
              ],
              if (sections.isNotEmpty) ...[
                const Text('Shared Sections').h4.semiBold,
                const SizedBox(height: 10),
                ...sections.map(
                  (s) => _PublicSectionCard(section: s as Map<String, dynamic>),
                ),
              ],
              if (records.isEmpty && sections.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: const Text(
                      'No items are shared in this link.',
                    ).muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicSectionCard extends StatelessWidget {
  final Map<String, dynamic> section;

  const _PublicSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = section['name'] as String? ?? 'Section';
    final key = section['key'] as String? ?? '';
    // The public endpoint returns `records` as a list of IDs on the section
    // payload. The viewer cannot dereference those without the parent's
    // owner access — that's by design (records are owner-only). We show
    // any records inlined by the server under `records` if it happens to
    // be a list of maps.
    final recordsList = section['records'];
    final List<Map<String, dynamic>> inline = recordsList is List
        ? recordsList.whereType<Map<String, dynamic>>().toList(growable: false)
        : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                BootstrapIcons.folder,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(name).semiBold.large,
              const SizedBox(width: 6),
              Text('($key)').muted.small.mono,
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: inline.isEmpty
                  ? [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'No records inside this section.',
                        ).muted.small,
                      ),
                    ]
                  : inline.map((r) => _PublicRecordCard(record: r)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicRecordCard extends StatefulWidget {
  final Map<String, dynamic> record;

  const _PublicRecordCard({required this.record});

  @override
  State<_PublicRecordCard> createState() => _PublicRecordCardState();
}

class _PublicRecordCardState extends State<_PublicRecordCard> {
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    final format = widget.record['format'] as String? ?? 'default';
    _isObscured = format == 'hidden';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.record['label'] as String? ?? 'Record';
    final key = widget.record['key'] as String? ?? '';
    final value = widget.record['value'] as String? ?? '';
    final type = widget.record['type'] as String? ?? 'text';
    final format = widget.record['format'] as String? ?? 'default';
    final isHiddenFormat = format == 'hidden';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label).semiBold,
                        const SizedBox(height: 2),
                        Text(key).mono.muted.xSmall,
                      ],
                    ),
                  ),
                  SecondaryBadge(child: Text(type)),
                  const SizedBox(width: 8),
                  GhostButton(
                    density: ButtonDensity.icon,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      AppToast.success(context, 'Copied to clipboard');
                    },
                    child: const Icon(BootstrapIcons.copy, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isObscured ? '••••••••••••••••' : value,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: _isObscured
                              ? theme.colorScheme.mutedForeground
                              : theme.colorScheme.foreground,
                        ),
                      ).small,
                    ),
                    if (isHiddenFormat) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isObscured = !_isObscured;
                          });
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(
                            _isObscured
                                ? BootstrapIcons.eye
                                : BootstrapIcons.eyeSlash,
                            size: 14,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
