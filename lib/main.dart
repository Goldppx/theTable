import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'models/course.dart';
import 'services/campus_gateway.dart';

void main() => runApp(const TheTableApp());

class TheTableApp extends StatelessWidget {
  const TheTableApp({super.key});
  static const _seed = Color(0xFF208AEF);

  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) => MaterialApp(
          title: '应大通 Flutter',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: ThemeData(
            colorScheme: lightDynamic ?? ColorScheme.fromSeed(seedColor: _seed),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: _seed,
                  brightness: Brightness.dark,
                ),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _tab = 0;
  final CampusGateway _gateway = DemoCampusGateway();

  @override
  Widget build(BuildContext context) {
    final pages = [
      SchedulePage(gateway: _gateway),
      const MapPage(),
      const CalendarPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: '课程'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: '地图'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }
}

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.gateway});
  final CampusGateway gateway;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Course>>(
        future: gateway.loadCourses(),
        builder: (context, snapshot) {
          final courses = snapshot.data ?? const <Course>[];
          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('本周课程')),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.separated(
                  itemCount: courses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => CourseCard(course: courses[index]),
                ),
              ),
            ],
          );
        },
      );
}

class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(child: Text('${course.weekday}')),
          title: Text(course.name, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(
            '${course.teacher} · ${course.room}\n'
            '第 ${course.startPeriod}–${course.endPeriod} 节',
          ),
          isThreeLine: true,
        ),
      );
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderPage(
        icon: Icons.location_on_outlined,
        title: '校园地图',
        message: '地图提供者和地点数据通过 CampusGateway 接入。',
      );
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderPage(
        icon: Icons.event_note_outlined,
        title: '校历',
        message: '学期、考试与活动将在这里统一显示。',
      );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
          const SizedBox(height: 16),
          Center(child: Text('尚未登录', style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.login),
            label: const Text('连接校园账户'),
          ),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('动态取色已启用'),
            subtitle: Text('Android 12 及以上系统自动跟随壁纸配色'),
          ),
        ],
      );
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
