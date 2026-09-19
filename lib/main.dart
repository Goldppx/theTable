import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'auth/campus_auth.dart';
import 'auth/login_page.dart';
import 'models/course.dart';
import 'services/campus_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TheTableApp());
}

class TheTableApp extends StatelessWidget {
  const TheTableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final fallbackLight = ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        );
        final fallbackDark = ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        );
        return MaterialApp(
          title: 'theTable',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightDynamic ?? fallbackLight,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkDynamic ?? fallbackDark,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _pages = [
    SchedulePage(),
    DataPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = ['课表', '数据结构', '我的'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '课表',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage),
            label: '数据',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _gateway = CampusGateway();
  late Future<List<Course>> _courses;

  @override
  void initState() {
    super.initState();
    _courses = _gateway.loadSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Course>>(
      future: _courses,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final courses = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _courses = _gateway.loadSchedule());
            await _courses;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) => CourseCard(course: courses[index]),
          ),
        );
      },
    );
  }
}

class CourseCard extends StatelessWidget {
  const CourseCard({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 78,
                decoration: BoxDecoration(
                  color: course.color ?? colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(course.teacher),
                    const SizedBox(height: 8),
                    Text('${course.weekday} · ${course.period}'),
                    Text(course.location, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('任课教师：${course.teacher}'),
            Text('时间：${course.weekday} ${course.period}'),
            Text('地点：${course.location}'),
          ],
        ),
      ),
    );
  }
}

class DataPage extends StatelessWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('数据结构', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('课程、周次和节次均采用结构化模型，后续可接入校园服务后端。'),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('课程模型'),
            subtitle: const Text('名称、教师、地点、星期、节次与配色'),
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = CampusAuthService();
  CampusProfile? _profile;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreProfile();
  }

  Future<void> _restoreProfile() async {
    final profile = await _auth.restoreProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _restoring = false;
      });
    }
  }

  Future<void> _login() async {
    final profile = await Navigator.of(context).push<CampusProfile>(
      MaterialPageRoute(builder: (_) => CampusLoginPage(auth: _auth)),
    );
    if (profile != null && mounted) {
      setState(() => _profile = profile);
    }
  }

  Future<void> _clearProfile() async {
    await _auth.clearProfile();
    if (mounted) setState(() => _profile = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const Center(child: CircularProgressIndicator());

    final profile = _profile;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                child: Icon(
                  profile == null ? Icons.person_outline : Icons.verified_outlined,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile == null ? '尚未登录' : profile.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (profile != null) ...[
                const SizedBox(height: 4),
                Text(profile.studentNumber),
                if (profile.major != null) Text(profile.major!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (profile == null)
          FilledButton.icon(
            onPressed: _login,
            icon: const Icon(Icons.login),
            label: const Text('连接校园账户'),
          )
        else
          OutlinedButton.icon(
            onPressed: _clearProfile,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清除本地资料'),
          ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '认证由学校官方 CAS 页面完成。密码、滑块和验证码仅提交至学校域名；应用只保存认证后的基础身份信息。',
            ),
          ),
        ),
      ],
    );
  }
}
