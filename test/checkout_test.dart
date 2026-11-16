import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercy_pay_flutter/mercy_pay_flutter.dart';

Widget app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('asks the server, then opens the payment page', (tester) async {
    final opened = <Uri>[];
    final session = Completer<String>();

    await tester.pumpWidget(app(MercyPayCheckoutButton(
      createCheckoutUrl: () => session.future,
      opener: (uri) async {
        opened.add(uri);
        return true;
      },
      child: const Text('Payer'),
    )));

    await tester.tap(find.text('Payer'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    session.complete('https://mercy-pay.com/paiement/01J9');
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://mercy-pay.com/paiement/01J9')]);
    expect(find.text('Payer'), findsOneWidget);
  });

  testWidgets('gives the error back and lets the customer try again', (tester) async {
    final errors = <Object>[];

    await tester.pumpWidget(app(MercyPayCheckoutButton(
      createCheckoutUrl: () async => throw Exception('Serveur indisponible'),
      onError: errors.add,
      opener: (_) async => fail('must not open'),
      child: const Text('Payer'),
    )));

    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();

    expect(errors, hasLength(1));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  test('only http and https addresses are opened', () {
    expect(MercyPayCheckout.checkoutUri('https://mercy-pay.com/paiement/x').host, 'mercy-pay.com');
    expect(() => MercyPayCheckout.checkoutUri('javascript:alert(1)'), throwsArgumentError);
    expect(() => MercyPayCheckout.checkoutUri('pas une adresse'), throwsArgumentError);
  });
}
