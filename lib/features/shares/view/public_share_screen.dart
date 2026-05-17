import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../../core/di/service_locator.dart';

class PublicShareScreen extends StatefulWidget {
  final String shareSlug;

  const PublicShareScreen({super.key, required this.shareSlug});

  @override
  State<PublicShareScreen> createState() => _PublicShareScreenState();
}

class _PublicShareScreenState extends State<PublicShareScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _shareData;

  @override
  void initState() {
    super.initState();
    _loadShareDetails();
  }

  Future<void> _loadShareDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ServiceLocator.sharesRepository.getPublicLinkDetails(
        widget.shareSlug,
      );
      setState(() {
        _shareData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
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
            Text('Retrieving shared vault items...').muted,
          ],
        ),
      );
    }

    if (_error != null) {
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
                  const Text('Access Denied or Link Expired').h4.semiBold,
                  const SizedBox(height: 8),
                  Text(
                    'This share link could not be loaded. Please ensure the URL is correct or contact the sender.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.mutedForeground),
                  ).small,
                  const SizedBox(height: 20),
                  PrimaryButton(
                    onPressed: _loadShareDetails,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final share = _shareData!;
    final label = share['label'] as String? ?? 'Shared Items';
    final expand = share['expand'] as Map<String, dynamic>? ?? {};
    final sections = expand['sections'] as List<dynamic>? ?? [];
    final directRecords = expand['records'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                        'This is a read-only secure view of shared items from a Revoked vault.',
                        style: TextStyle(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ).small,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Direct Records
              if (directRecords.isNotEmpty) ...[
                const Text('Shared Records').h4.semiBold,
                const SizedBox(height: 10),
                ...directRecords.map(
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

              if (directRecords.isEmpty && sections.isEmpty)
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
    final expand = section['expand'] as Map<String, dynamic>? ?? {};
    final records = expand['records'] as List<dynamic>? ?? [];

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
              children: records.isEmpty
                  ? [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No records inside this section.',
                        ).muted.small,
                      ),
                    ]
                  : records
                        .map(
                          (r) => _PublicRecordCard(
                            record: r as Map<String, dynamic>,
                          ),
                        )
                        .toList(),
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
    // Only default to obscured if the format is 'hidden'
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
                      showToast(
                        context: context,
                        builder: (context, overlay) => const SurfaceCard(
                          child: Basic(
                            leading: Icon(BootstrapIcons.check, size: 16),
                            title: Text('Value copied to clipboard'),
                          ),
                        ),
                      );
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
