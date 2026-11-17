import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercy_pay_flutter/mercy_pay_flutter.dart';

final secret = 'cs_${'0' * 26}_secret_${'a' * 32}';

void main() {
  test('builds the form address for the Flutter bridge, with the appearance it understands', () {
    final url = MercyPayEmbedded.url(
      secret,
      appearance: const MercyPayAppearance(theme: Brightness.dark, color: '#1A7F37', radius: 40),
    );

    expect(url.toString(), startsWith('https://mercy-pay.com/integre/v1/paiement?'));
    expect(url.queryParameters['client_secret'], secret);
    expect(url.queryParameters['bridge'], 'flutter');
    expect(url.queryParameters['theme'], 'dark');
    expect(url.queryParameters['color'], '1a7f37');
    expect(url.queryParameters['radius'], '24');
    expect(MercyPayEmbedded.url(secret, appearance: const MercyPayAppearance(color: 'red')).queryParameters.containsKey('color'), isFalse);
  });

  test('refuses anything that is not a session client secret', () {
    expect(() => MercyPayEmbedded.url('mp_sandbox_123'), throwsArgumentError);
  });

  test('hands each message to the right callback and ignores anything else', () {
    final seen = <String>[];
    MercyPayEvent? succeeded;
    MercyPayEvent? failed;
    MercyPayEvent? error;
    final widget = MercyPayEmbeddedCheckout(
      clientSecret: secret,
      onEvent: (event) => seen.add(event.type),
      onSuccess: (event) => succeeded = event,
      onFailure: (event) => failed = event,
      onError: (event) => error = event,
    );

    dispatchMercyPayMessage(widget, '{"source":"mercy-pay","version":1,"type":"payment_failed","checkout_session":"cs_1","payment":"pay_1","message":"Solde insuffisant."}');
    dispatchMercyPayMessage(widget, '{"source":"mercy-pay","version":1,"type":"payment_succeeded","checkout_session":"cs_1","payment":"pay_2"}');
    dispatchMercyPayMessage(widget, '{"source":"mercy-pay","version":1,"type":"error","code":"session_unavailable"}');
    dispatchMercyPayMessage(widget, '{"source":"autre","type":"payment_succeeded"}');
    dispatchMercyPayMessage(widget, 'pas du json');

    expect(seen, ['payment_failed', 'payment_succeeded', 'error']);
    expect(failed?.message, 'Solde insuffisant.');
    expect(succeeded?.payment, 'pay_2');
    expect(error?.code, 'session_unavailable');
  });
}
