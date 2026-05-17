import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Key? _selectedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.vault)) {
      _selectedKey = const ValueKey(0);
    } else if (location.startsWith(AppRoutes.shares)) {
      _selectedKey = const ValueKey(1);
    } else if (location.startsWith(AppRoutes.settings)) {
      _selectedKey = const ValueKey(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Column(
        children: [
          Expanded(child: widget.child),

          const Divider(height: 1),

          NavigationBar(
            alignment: NavigationBarAlignment.spaceAround,
            labelType: NavigationLabelType.all,
            expanded: true,
            selectedKey: _selectedKey,
            onSelected: (key) {
              if (key == const ValueKey(0)) {
                context.go(AppRoutes.vault);
              } else if (key == const ValueKey(1)) {
                context.go(AppRoutes.shares);
              } else if (key == const ValueKey(2)) {
                context.go(AppRoutes.settings);
              }
            },
            children: [
              NavigationItem(
                key: const ValueKey(0),
                style: const ButtonStyle.ghost(density: ButtonDensity.icon),
                selectedStyle: const ButtonStyle.secondary(
                  density: ButtonDensity.icon,
                ),
                label: const Text('Vault'),
                child: const Icon(BootstrapIcons.safe),
              ),
              NavigationItem(
                key: const ValueKey(1),
                style: const ButtonStyle.ghost(density: ButtonDensity.icon),
                selectedStyle: const ButtonStyle.secondary(
                  density: ButtonDensity.icon,
                ),
                label: const Text('Shares'),
                child: const Icon(BootstrapIcons.share),
              ),
              NavigationItem(
                key: const ValueKey(2),
                style: const ButtonStyle.ghost(density: ButtonDensity.icon),
                selectedStyle: const ButtonStyle.secondary(
                  density: ButtonDensity.icon,
                ),
                label: const Text('Account'),
                child: const Icon(BootstrapIcons.personGear),
              ),
            ],
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
