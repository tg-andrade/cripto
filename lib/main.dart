import 'dart:async';
import 'package:flutter/material.dart';
import 'providers/app_controller.dart';
import 'services/crypto_api_service.dart';
import 'services/local_storage_service.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CryptoHubApp(
      controller: AppController(
        api: CryptoApiService(),
        storage: LocalStorageService(),
      ),
      ownsController: true,
    ),
  );
}

class CryptoHubApp extends StatefulWidget {
  const CryptoHubApp({
    super.key,
    required this.controller,
    this.initialize = true,
    this.ownsController = false,
  });
  final AppController controller;
  final bool initialize;
  final bool ownsController;
  @override
  State<CryptoHubApp> createState() => _CryptoHubAppState();
}

class _CryptoHubAppState extends State<CryptoHubApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialize) unawaited(widget.controller.initialize());
  }

  @override
  void dispose() {
    if (widget.ownsController) {
      widget.controller.dispose();
      widget.controller.api.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CryptoHub',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: AppShell(controller: widget.controller),
  );
}
