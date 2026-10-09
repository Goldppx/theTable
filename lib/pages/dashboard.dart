import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../features/settings_pages.dart';
import '../ui/app_style.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.state,
    required this.onSchedule,
    required this.onMap,
    super.key,
  });
  final CampusState state;
  final VoidCallback onSchedule, onMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = Theme.of(context).colorScheme;
    final today =
        state.courses
            .where(
              (c) =>
                  c.weekday == DateTime.now().weekday &&
                  c.occursIn(state.currentWeek),
            )
            .toList()
          ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
    return PageBody(
      children: [
        Text('应大通', style: theme.textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(
          '第 ${state.currentWeek} 周 · 从容安排校园生活',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calendar_today_outlined, color: colors.primary),
                const SizedBox(height: 16),
                Text('今日课程', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  state.courses.isEmpty
                      ? '同步课表，开启你的学期安排'
                      : today.isEmpty
                      ? '今天暂无课程，留些时间给自己'
                      : '今天有 ${today.length} 项课程安排',
                  style: theme.textTheme.bodyLarge,
                ),
                for (final course in today)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: 40,
                          decoration: BoxDecoration(
                            color: course.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                '${course.period} · ${course.room.isEmpty ? '地点待提供' : course.room}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onSchedule,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('进入课表 ›'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text('校园服务', style: theme.textTheme.titleLarge)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShortcutsPage(state: state),
                ),
              ),
              child: const Text('管理'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Icon(Icons.map_outlined, color: colors.primary),
            title: const Text('校园地图'),
            subtitle: const Text('查找地点与出行导航'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onMap,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.shortcuts
              .map(
                (s) => ActionChip(
                  avatar: const Icon(Icons.open_in_new, size: 18),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => launchShortcut(context, s),
                ),
              )
              .toList(),
        ),
        if (state.storageError != null) ...[
          const SizedBox(height: 24),
          Text(state.storageError!, style: TextStyle(color: colors.error)),
          TextButton(onPressed: onSchedule, child: const Text('打开课表并恢复数据')),
        ],
        const SizedBox(height: 32),
        Center(
          child: Text(
            'theTable $appVersion',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
