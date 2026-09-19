import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'auth/campus_auth.dart';
import 'auth/jwxt_page.dart';
import 'auth/login_page.dart';

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
        final fallback = ColorScheme.fromSeed(
          seedColor: const Color(0xff9fc6ff),
          brightness: Brightness.dark,
        );
        return MaterialApp(
          title: '应大通',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            colorScheme: darkDynamic ?? fallback,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xff101318),
            useMaterial3: true,
            cardTheme: const CardThemeData(
              color: Color(0xff1b2027),
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
            ),
          ),
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
  int _index = 0;

  void _openSchedule() {
    setState(() => _index = 2);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onOpenSchedule: _openSchedule),
      const CampusPage(),
      const ScheduleTab(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 78,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: '校园',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: '课表',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.onOpenSchedule, super.key});

  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const PageTitle(title: '应大通', subtitle: '教务信息，一处查看'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text('开发组公告', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Card(
            color: colors.primaryContainer,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: Icon(Icons.campaign_outlined, color: colors.onPrimaryContainer),
              title: Text('欢迎使用', style: TextStyle(color: colors.onPrimaryContainer)),
              subtitle: Text(
                '校园数据直接来自学校服务',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
              trailing: Icon(Icons.expand_more, color: colors.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: 34),
        const _SectionTitle('教务'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ActionCard(
            icon: Icons.calendar_month_rounded,
            title: '我的课表',
            subtitle: '进入学校教务系统，查看并刷新真实课表',
            action: '进入课表',
            onTap: onOpenSchedule,
          ),
        ),
        const SizedBox(height: 30),
        const _SectionTitle('校园'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ActionCard(
            icon: Icons.map_outlined,
            title: '校园地图',
            subtitle: '常用地点与校园服务入口',
            action: '打开地图',
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colors.onSecondaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 14),
                    Text(
                      action + ' ›',
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
                    ),
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

class CampusPage extends StatelessWidget {
  const CampusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageTitle(title: '校园地图', subtitle: '常用地点与校园服务'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.map_rounded, size: 42, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 18),
                  Text('地图服务准备中', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('下一次更新将接入校园地点标记与路线导航。'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const PageTitle(title: '我的课表', subtitle: '实时连接学校教务系统'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sync_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 18),
                  Text('官方课表同步', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('使用已登录的统一认证会话打开教务系统。刷新、学期选择和课表内容均由学校系统返回。'),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OfficialJwxtPage()),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('打开并同步课表'),
                  ),
                ],
              ),
            ),
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
    if (mounted) setState(() {
      _profile = profile;
      _restoring = false;
    });
  }

  Future<void> _login() async {
    final profile = await Navigator.of(context).push<CampusProfile>(
      MaterialPageRoute(builder: (_) => CampusLoginPage(auth: _auth)),
    );
    if (profile != null && mounted) setState(() => _profile = profile);
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
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const PageTitle(title: '我的', subtitle: '账号与应用设置'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: profile == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 48),
                        const SizedBox(height: 16),
                        Text('尚未连接校园账户', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _login,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('连接校园账户'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 6),
                        Text(profile.studentNumber, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 24),
                        _InfoRow('专业', profile.major ?? '学校门户未提供'),
                        const SizedBox(height: 12),
                        const _InfoRow('认证状态', '已连接'),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              _SettingTile(icon: Icons.palette_outlined, title: '外观', subtitle: '深色模式与动态取色'),
              const SizedBox(height: 12),
              _SettingTile(icon: Icons.settings_outlined, title: '设置', subtitle: '本地数据与隐私'),
              if (profile != null) ...[
                const SizedBox(height: 12),
                _SettingTile(
                  icon: Icons.delete_outline,
                  title: '清除本地资料',
                  subtitle: '保留学校网页会话',
                  onTap: _clearProfile,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
