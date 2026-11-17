# Mercy Pay pour Flutter

Encaissez avec [Mercy Pay](https://mercy-pay.com) depuis votre app Flutter, sur Android et iOS, de deux façons :

- `MercyPayEmbeddedCheckout` affiche le formulaire de paiement dans votre app : mobile money et carte, 3D Secure comprise ;
- `MercyPayCheckoutButton` ouvre la page de paiement hébergée dans le navigateur intégré.

Aucune donnée de paiement ne passe par votre app.

```sh
flutter pub add mercy_pay_flutter
```

## Le principe

1. Votre app demande à **votre serveur** de créer la session de paiement. La clé API reste sur le serveur, jamais dans l'app : une app se décompile.
2. Le serveur renvoie `checkout_url`.
3. L'app ouvre cette page dans le navigateur intégré (Custom Tabs sur Android, Safari View Controller sur iOS).
4. Après le paiement, la page renvoie le client vers votre `success_url`. Faites-en un lien qui rouvre votre app.
5. L'app demande l'état de la commande à votre serveur. Seul le webhook `payment.succeeded`, reçu et vérifié par le serveur, prouve le paiement.

Côté serveur, utilisez un SDK officiel : [Dart](https://github.com/mercy-pay/mercy-pay-dart), [Node.js](https://github.com/mercy-pay/mercy-pay-node), [PHP](https://github.com/mercy-pay/mercy-pay-php), [Python](https://github.com/mercy-pay/mercy-pay-python)…

## Le formulaire dans votre app

Votre serveur crée la session avec `ui_mode: "embedded"` et renvoie son `client_secret`. Affichez le formulaire sur un écran à lui :

```dart
import 'package:mercy_pay_flutter/mercy_pay_flutter.dart';

Scaffold(
  appBar: AppBar(title: const Text('Paiement')),
  body: MercyPayEmbeddedCheckout(
    clientSecret: clientSecret,
    appearance: const MercyPayAppearance(radius: 12),
    onSuccess: (event) => Navigator.of(context).pop(true),
    onError: (event) => Navigator.of(context).pop(false), // session introuvable : créez-en une autre
  ),
)
```

Les événements : `onReady`, `onProcessing`, `onSuccess`, `onFailure`, `onExpired`, `onError`, et `onEvent` pour tous. Chacun donne `checkoutSession`, `payment` et, en cas d'échec, `message`.

- Android : l'app doit avoir la permission `INTERNET`, et `minSdkVersion` 21 au moins.
- Apple Pay et Google Pay ne s'affichent pas dans une vue web : le client paie par mobile money ou par carte.
- `onSuccess` met à jour votre app. Seul le webhook `payment.succeeded`, reçu par votre serveur, prouve le paiement.

Voir le [guide du paiement intégré](https://docs.mercy-pay.com/payments/embedded).

## Le bouton

```dart
import 'package:mercy_pay_flutter/mercy_pay_flutter.dart';

MercyPayCheckoutButton(
  createCheckoutUrl: () => api.createCheckout(order.id), // renvoie session.checkout_url
  onError: (error) => showSnackBar("Le paiement n'a pas pu démarrer, réessayez."),
  child: const Text('Payer 15 000 FCFA'),
)
```

Pendant l'appel au serveur, le bouton est désactivé et affiche un indicateur. Seule une adresse `http` ou `https` est ouverte. `external: true` ouvre le navigateur du téléphone plutôt que la vue intégrée.

## Sans le bouton

```dart
final url = await api.createCheckout(order.id);
await MercyPayCheckout.open(url);
```

## Revenir dans l'app

Donnez comme `success_url` un lien que votre app sait ouvrir : un App Link Android ou un Universal Link iOS (`https://boutique.example/paiement/retour`), ou un schéma propre à l'app (`boutique://paiement/retour`). Le paquet [`app_links`](https://pub.dev/packages/app_links) vous signale l'ouverture : demandez alors l'état de la commande à votre serveur.
