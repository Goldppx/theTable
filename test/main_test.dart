import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/main.dart';

void main() {
  testWidgets('renders the course tab', (tester) async {
    await tester.pumpWidget(const TheTableApp());
    await tester.pumpAndSettle();
    expect(find.text('本周课程'), findsOneWidget);
    expect(find.text('数据结构'), findsOneWidget);
  });
}
