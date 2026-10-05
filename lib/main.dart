import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'pages/campus_map.dart';
import 'pages/dashboard.dart';
import 'pages/profile.dart';
import 'pages/schedule.dart';
import 'services/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TheTableApp());
}

class TheTableApp extends StatefulWidget {
  const TheTableApp({this.state, super.key});
  final CampusState? state;
  @override
  State<TheTableApp> createState() => _TheTableAppState();
}
class _TheTableAppState extends State<TheTableApp> {
  late final CampusState state;
  @override
  void initState() {
    super.initState();
    state = widget.state ?? CampusState();
    if (!state.ready) state.restore();
  }
  @override
  void dispose() {
    if (widget.state == null) state.dispose();
    super.dispose();
  }
  ThemeData theme(ColorScheme? dynamic, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = (state.dynamicColor ? dynamic : null) ?? ColorScheme.fromSeed(
      seedColor: const Color(0xffa3c7ff), brightness: brightness);
    return ThemeData(useMaterial3: true, brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: dark ? const Color(0xff101418) : const Color(0xfff6f8fc),
      cardTheme: CardThemeData(color: dark ? const Color(0xff191e23) : Colors.white,
        elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      appBarTheme: const AppBarTheme(centerTitle: false),
      textTheme: TextTheme(
        displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: colors.onSurface),
        headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: colors.onSurfaceVariant)),
    );
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: state,
    builder: (context, _) => DynamicColorBuilder(builder: (light, dark) => MaterialApp(
      title: '应大通', debugShowCheckedModeBanner: false, themeMode: state.themeMode,
      theme: theme(light, Brightness.light), darkTheme: theme(dark, Brightness.dark),
      home: HomeScreen(state: state))));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.state, super.key});
  final CampusState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final visited = <int>{0};
  void select(int value) => setState(() { index = value; visited.add(value); });
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: index, children: [
        DashboardPage(state: state, onSchedule: () => select(2), onMap: () => select(1)),
        if (visited.contains(1)) CampusMapPage(state: state) else const SizedBox.shrink(),
        if (visited.contains(2)) SchedulePage(state: state) else const SizedBox.shrink(),
        if (visited.contains(3)) ProfilePage(state: state) else const SizedBox.shrink(),
      ])),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color,
          border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: .5)))),
        child: SafeArea(top: false, child: SizedBox(height: 70, child: Row(
          children: List.generate(4, (i) {
            const labels = ['首页', '地图', '日历', '我的'];
            const icons = [Icons.home_outlined, Icons.map_outlined, Icons.calendar_month_outlined, Icons.person_outline];
            const selected = [Icons.home_rounded, Icons.map_rounded, Icons.calendar_month_rounded, Icons.person];
            final active = index == i;
            final color = active ? colors.primary : colors.onSurfaceVariant;
            return Expanded(child: Semantics(selected: active, button: true,
              child: InkWell(onTap: () => select(i), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(active ? selected[i] : icons[i], color: color, size: 27),
                const SizedBox(height: 3), Text(labels[i], style: TextStyle(color: color, fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
              ]))));
          })))),
      ),
    );
  }
}
