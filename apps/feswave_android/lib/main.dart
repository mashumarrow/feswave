import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'live/live_page.dart';
import 'profile/pages.dart';
import 'memories/page.dart';
import 'ui/shared.dart';

void main() => runApp(const ProviderScope(child: Feswave()));
final router = GoRouter(
  initialLocation: '/live',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Shell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/live', builder: (_, _) => const LivePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/memories', builder: (_, _) => const MemoriesPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfilePage(),
              routes: [
                GoRoute(path: 'edit', builder: (_, _) => const ProfileEditor()),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class Feswave extends StatelessWidget {
  const Feswave({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'FESWAVE',
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: lilac,
        brightness: Brightness.dark,
      ).copyWith(primary: lilac, surface: panel),
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
      textTheme: const TextTheme(bodySmall: noteStyle),
      dividerColor: const Color(0xff352841),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xff412c4c)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: const Color(0xff100d19),
        indicatorColor: const Color(0xff492249),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? const Color(0xffff99f4)
                : const Color(0xffa293b1),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            color: s.contains(WidgetState.selected)
                ? const Color(0xffff99f4)
                : const Color(0xffa293b1),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: const Color(0xff67368a),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xffad6eca)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xffe5cfed),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: const Color(0xff46214f),
        backgroundColor: panel,
        showCheckmark: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff100d19),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
  );
}

class Shell extends StatelessWidget {
  const Shell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: shell),
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      destinations: const [
        NavigationDestination(icon: WaveIcon('live'), label: 'ライブ'),
        NavigationDestination(icon: WaveIcon('heart'), label: 'メモリ'),
        NavigationDestination(icon: WaveIcon('user'), label: 'プロフィール'),
      ],
    ),
  );
}
