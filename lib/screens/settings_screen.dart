import 'package:flutter/material.dart';

import '../services/api_key_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = ApiKeyStore();
  final _controller = TextEditingController();
  bool _loading = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await _store.read();
    if (!mounted) return;
    setState(() {
      _controller.text = key ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _store.write(_controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key saved.')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _clear() async {
    await _store.clear();
    if (!mounted) return;
    setState(() => _controller.text = '');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key cleared.')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'OpenRouter API key',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a key at openrouter.ai/keys. It is stored '
                    'encrypted on this device and never leaves it except '
                    'to call the OpenRouter API.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'sk-or-...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _clear,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
    );
  }
}
