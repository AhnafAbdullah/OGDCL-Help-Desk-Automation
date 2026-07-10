import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hdworkflow/app.dart';

void main() {
  testWidgets('App boots to the splash screen while auth resolves', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OgdclHelpDeskApp()));
    await tester.pump();

    // The router's initial location is the splash screen, which shows a
    // spinner while the auth bootstrap call is in flight.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
