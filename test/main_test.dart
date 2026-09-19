import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/main.dart';

void main() {
  testWidgets('renders the course tab', (tester) async {
    await tester.pumpWidget(const TheTableApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('数据结构'), findsWidgets);
    expect(find.text('操作系统'), findsOneWidget);
  });
}
