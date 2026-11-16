/// Mercy Pay pour Flutter : ouvrir la page de paiement hébergée.
///
/// Votre app ne détient jamais la clé API. Elle demande à votre serveur de créer la session
/// de paiement, puis ouvre l'adresse `checkout_url` que le serveur lui renvoie.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL; replaced in tests.
typedef UrlOpener = Future<bool> Function(Uri url);

/// What your server answers once it has created the session: its `checkout_url`.
typedef CreateCheckoutUrl = Future<String> Function();

/// Opens the Mercy Pay payment page.
class MercyPayCheckout {
  const MercyPayCheckout._();

  /// Only an http(s) address is opened: anything else is refused.
  static Uri checkoutUri(String checkoutUrl) {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http')) || uri.host.isEmpty) {
      throw ArgumentError.value(checkoutUrl, 'checkoutUrl', 'Adresse de paiement invalide.');
    }
    return uri;
  }

  /// Opens the page in the in-app browser (Custom Tabs on Android, Safari View Controller
  /// on iOS), or in the web browser with [external]. Returns false when nothing could open it.
  static Future<bool> open(String checkoutUrl, {bool external = false}) {
    return launchUrl(
      checkoutUri(checkoutUrl),
      mode: external ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView,
    );
  }
}

/// A button that asks your server for a session, then opens the payment page.
///
/// ```dart
/// MercyPayCheckoutButton(
///   createCheckoutUrl: () => api.createCheckout(orderId), // returns session.checkout_url
///   child: const Text('Payer 15 000 FCFA'),
/// )
/// ```
///
/// When the customer comes back (your success_url opens the app), ask your server for the
/// order's status: only the payment.succeeded webhook it received proves the payment.
class MercyPayCheckoutButton extends StatefulWidget {
  const MercyPayCheckoutButton({
    super.key,
    required this.createCheckoutUrl,
    required this.child,
    this.onError,
    this.style,
    this.external = false,
    this.opener,
  });

  final CreateCheckoutUrl createCheckoutUrl;
  final Widget child;
  final void Function(Object error)? onError;
  final ButtonStyle? style;

  /// Opens the page in the web browser instead of inside the app.
  final bool external;

  /// Replaces how the page is opened, for tests.
  final UrlOpener? opener;

  @override
  State<MercyPayCheckoutButton> createState() => _MercyPayCheckoutButtonState();
}

class _MercyPayCheckoutButtonState extends State<MercyPayCheckoutButton> {
  bool _pending = false;

  Future<void> _start() async {
    setState(() => _pending = true);
    try {
      final url = await widget.createCheckoutUrl();
      final uri = MercyPayCheckout.checkoutUri(url);
      final opened = widget.opener != null
          ? await widget.opener!(uri)
          : await MercyPayCheckout.open(uri.toString(), external: widget.external);
      if (!opened) throw StateError("La page de paiement n'a pas pu s'ouvrir.");
    } catch (error) {
      widget.onError?.call(error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: widget.style,
      onPressed: _pending ? null : _start,
      child: _pending
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : widget.child,
    );
  }
}
