# Mercy Pay pour Flutter

Ouvrez la page de paiement hébergée de [Mercy Pay](https://mercy-pay.com) depuis votre app Flutter, sur Android et iOS. Mobile money et carte, sans aucune donnée de paiement dans votre app.

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
