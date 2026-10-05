import 'package:flutter/material.dart';
import '../providers/app_controller.dart';
import '../theme/app_theme.dart';

Future<void> showApiKeySheet(BuildContext context, AppController controller) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ApiKeySheet(controller: controller),
    );

class _ApiKeySheet extends StatefulWidget {
  const _ApiKeySheet({required this.controller});
  final AppController controller;
  @override
  State<_ApiKeySheet> createState() => _ApiKeySheetState();
}

class _ApiKeySheetState extends State<_ApiKeySheet> {
  final _key = TextEditingController();
  bool _obscured = true, _saving = false;
  String? _error;
  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_key.text.trim().isEmpty) {
      setState(() => _error = 'Informe a chave da CryptoCompare.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.controller.setApiKey(_key.text.trim());
    if (!mounted) return;
    if (widget.controller.marketError != null) {
      setState(() {
        _saving = false;
        _error = widget.controller.marketError;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.key_rounded, color: AppColors.accent, size: 30),
          const SizedBox(height: 16),
          Text(
            'Acesso à CryptoCompare',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text(
            'Use a chave gerada em sua conta da CryptoCompare. Ela será usada nesta sessão. A configuração de desenvolvimento está no README do projeto.',
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('api-key-input'),
            controller: _key,
            enabled: !_saving,
            enableIMEPersonalizedLearning: false,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Chave da API',
              errorText: _error,
              errorMaxLines: 5,
              suffixIcon: IconButton(
                tooltip: _obscured ? 'Mostrar chave' : 'Ocultar chave',
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.controller.hasApiKey
                ? 'Uma chave já está configurada. Salvar substitui o acesso nesta sessão.'
                : 'Encontre sua chave em CryptoCompare → API → API keys.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Consultando…' : 'Salvar e consultar'),
            ),
          ),
        ],
      ),
    ),
  );
}
