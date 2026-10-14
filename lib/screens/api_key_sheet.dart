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
  final _keys = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final keys = _keys.text
        .split(RegExp(r'[\s,;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (keys.isEmpty) {
      setState(() => _error = 'Cole ao menos uma chave da CryptoCompare.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.controller.setApiKeys(keys);
    if (!mounted) return;
    if (widget.controller.apiKeyStorageError != null ||
        widget.controller.marketError != null) {
      setState(() {
        _saving = false;
        _error = widget.controller.apiKeyStorageError ??
            widget.controller.marketError;
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
            'Cole a lista uma única vez. O app salva as chaves com proteção neste aparelho, carrega automaticamente ao abrir e alterna entre elas nas consultas. Elas não são incluídas no código nem no GitHub.',
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('api-key-input'),
            controller: _keys,
            enabled: !_saving,
            enableIMEPersonalizedLearning: false,
            minLines: 3,
            maxLines: 7,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Chaves da API',
              hintText: 'Uma chave por linha',
              errorText: _error,
              errorMaxLines: 5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.controller.hasApiKey
                ? '${widget.controller.apiKeyCount} chave(s) carregada(s) neste aparelho. Salvar substitui a lista.'
                : 'Encontre suas chaves em CryptoCompare → API → API keys.',
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
