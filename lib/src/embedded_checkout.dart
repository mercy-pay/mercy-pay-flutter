import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The look of the embedded form, on top of the shop's Brand Kit.
class MercyPayAppearance {
  const MercyPayAppearance({this.theme, this.color, this.radius});

  /// `light` or `dark`. Without it, the form follows the phone.
  final Brightness? theme;

  /// The main color, `#1a7f37` or `1a7f37`.
  final String? color;

  /// Corner radius of fields and buttons, from 0 to 24.
  final int? radius;
}

/// One message from the embedded form.
class MercyPayEvent {
  const MercyPayEvent({
    required this.type,
    this.checkoutSession,
    this.payment,
    this.message,
    this.code,
    this.raw = const {},
  });

  /// `ready`, `processing`, `payment_succeeded`, `payment_failed`, `expired`, `error`…
  final String type;

  /// The session (`cs_…`).
  final String? checkoutSession;

  /// The payment (`pay_…`), once there is one.
  final String? payment;

  /// Why the payment failed, for the customer.
  final String? message;

  /// On `error`: why the form can't open, for example `session_unavailable`.
  final String? code;

  /// The whole message, for fields added later.
  final Map<String, dynamic> raw;

  /// Reads one message, or returns null for anything that isn't from Mercy Pay.
  static MercyPayEvent? tryParse(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic> || data['source'] != 'mercy-pay' || data['type'] is! String) {
        return null;
      }
      return MercyPayEvent(
        type: data['type'] as String,
        checkoutSession: data['checkout_session'] as String?,
        payment: data['payment'] as String?,
        message: data['message'] as String?,
        code: data['code'] as String?,
        raw: data,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Where the embedded form lives.
class MercyPayEmbedded {
  const MercyPayEmbedded._();

  static const defaultBaseUrl = 'https://mercy-pay.com';

  static final _clientSecret = RegExp(r'^cs_[0-9A-Za-z]{26}_secret_[0-9A-Za-z]{32}$');

  /// The form's address for a session. Throws on a value that can't be a client secret.
  static Uri url(String clientSecret, {MercyPayAppearance? appearance, String baseUrl = defaultBaseUrl}) {
    if (!_clientSecret.hasMatch(clientSecret)) {
      throw ArgumentError.value(
        clientSecret,
        'clientSecret',
        'Passez le client_secret d\'une session créée avec ui_mode "embedded".',
      );
    }

    final color = appearance?.color?.replaceFirst('#', '');
    final radius = appearance?.radius;

    return Uri.parse(baseUrl).replace(path: '/integre/v1/paiement', queryParameters: {
      'client_secret': clientSecret,
      'bridge': 'flutter',
      if (appearance?.theme != null) 'theme': appearance!.theme == Brightness.dark ? 'dark' : 'light',
      if (color != null && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(color)) 'color': color.toLowerCase(),
      if (radius != null) 'radius': '${radius.clamp(0, 24)}',
    });
  }
}

/// The Mercy Pay payment form inside your app: mobile money and card, 3D Secure included.
/// Give it the room of a screen.
///
/// ```dart
/// MercyPayEmbeddedCheckout(
///   clientSecret: clientSecret, // from your server: a session with ui_mode "embedded"
///   onSuccess: (event) => Navigator.of(context).pop(true),
/// )
/// ```
///
/// onSuccess updates your app. Only the payment.succeeded webhook your server receives
/// proves the payment.
class MercyPayEmbeddedCheckout extends StatefulWidget {
  const MercyPayEmbeddedCheckout({
    super.key,
    required this.clientSecret,
    this.appearance,
    this.onReady,
    this.onProcessing,
    this.onSuccess,
    this.onFailure,
    this.onExpired,
    this.onError,
    this.onEvent,
    this.baseUrl = MercyPayEmbedded.defaultBaseUrl,
    this.controller,
  });

  final String clientSecret;
  final MercyPayAppearance? appearance;
  final ValueChanged<MercyPayEvent>? onReady;
  final ValueChanged<MercyPayEvent>? onProcessing;
  final ValueChanged<MercyPayEvent>? onSuccess;
  final ValueChanged<MercyPayEvent>? onFailure;
  final ValueChanged<MercyPayEvent>? onExpired;
  final ValueChanged<MercyPayEvent>? onError;

  /// Every message, before its own callback.
  final ValueChanged<MercyPayEvent>? onEvent;

  /// Another Mercy Pay address, for tests.
  final String baseUrl;

  /// Your own controller, to configure the web view further.
  final WebViewController? controller;

  @override
  State<MercyPayEmbeddedCheckout> createState() => _MercyPayEmbeddedCheckoutState();
}

class _MercyPayEmbeddedCheckoutState extends State<MercyPayEmbeddedCheckout> {
  late final WebViewController _controller = widget.controller ?? WebViewController();

  @override
  void initState() {
    super.initState();
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MercyPayBridge', onMessageReceived: (message) => _dispatch(message.message))
      ..setNavigationDelegate(NavigationDelegate(
        // Web pages only: a bank's 3D Secure step stays inside, nothing else opens.
        onNavigationRequest: (request) {
          final scheme = Uri.tryParse(request.url)?.scheme;
          return scheme == 'https' || scheme == 'http' || scheme == 'about'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ));
    _load();
  }

  @override
  void didUpdateWidget(MercyPayEmbeddedCheckout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientSecret != widget.clientSecret) {
      _load();
    }
  }

  void _load() {
    _controller.loadRequest(MercyPayEmbedded.url(
      widget.clientSecret,
      appearance: widget.appearance,
      baseUrl: widget.baseUrl,
    ));
  }

  void _dispatch(String message) {
    if (mounted) {
      dispatchMercyPayMessage(widget, message);
    }
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

/// Hands one message from the form to the widget's callbacks.
@visibleForTesting
void dispatchMercyPayMessage(MercyPayEmbeddedCheckout widget, String message) {
  final event = MercyPayEvent.tryParse(message);
  if (event == null) {
    return;
  }

  widget.onEvent?.call(event);
  switch (event.type) {
    case 'ready':
      widget.onReady?.call(event);
    case 'processing':
      widget.onProcessing?.call(event);
    case 'payment_succeeded':
      widget.onSuccess?.call(event);
    case 'payment_failed':
      widget.onFailure?.call(event);
    case 'expired':
      widget.onExpired?.call(event);
    case 'error':
      widget.onError?.call(event);
  }
}
