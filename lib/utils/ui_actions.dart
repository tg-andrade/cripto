import 'package:flutter/material.dart';
import '../providers/app_controller.dart';

void showFeedback(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> toggleFavorite(
  BuildContext context,
  AppController controller,
  String symbol,
) async {
  final wasFavorite = controller.favorites.contains(symbol);
  final saved = await controller.toggleFavorite(symbol);
  if (context.mounted) {
    showFeedback(
      context,
      !saved
          ? 'Não foi possível salvar seus favoritos. Tente novamente.'
          : (wasFavorite
                ? '$symbol removido dos favoritos.'
                : '$symbol adicionado aos favoritos.'),
    );
  }
}
