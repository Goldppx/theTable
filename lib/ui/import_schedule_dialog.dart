import 'package:flutter/material.dart';

class ImportScheduleDialog extends StatefulWidget {
  const ImportScheduleDialog({super.key});
  @override
  State<ImportScheduleDialog> createState() => _ImportScheduleDialogState();
}

class _ImportScheduleDialogState extends State<ImportScheduleDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('导入课表'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('粘贴课程 JSON。全部课程校验成功后保存，格式示例见仓库 README。'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '课程 JSON',
              hintText: '[{"name":"课程", "weekday":1, ...}]',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('导入'),
      ),
    ],
  );
}
