import 'package:flutter/material.dart';

import '../models/ai_model.dart';
import '../services/api_key_store.dart';
import '../services/openrouter_service.dart';
import 'game_screen.dart';
import 'model_picker_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = ApiKeyStore();
  String? _apiKey;
  AiModel? _white;
  AiModel? _black;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await _store.read();
    if (!mounted) return;
    setState(() => _apiKey = key);
  }

  OpenRouterService? _service() {
    final k = _apiKey;
    if (k == null || k.isEmpty) return null;
    return OpenRouterService(k);
  }

  Future<void> _pickModel({required bool forWhite}) async {
    final service = _service();
    if (service == null) {
      _promptForKey();
      return;
    }
    final picked = await Navigator.of(context).push<AiModel>(
      MaterialPageRoute(
        builder: (_) => ModelPickerScreen(
          service: service,
          title: forWhite ? 'Pick White model' : 'Pick Black model',
          initialSelectedId: forWhite ? _white?.id : _black?.id,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (forWhite) {
        _white = picked;
      } else {
        _black = picked;
      }
    });
  }

  void _promptForKey() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Set your OpenRouter API key first.')),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _load();
  }

  void _start() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _promptForKey();
      return;
    }
    if (_white == null || _black == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a model for both sides.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        apiKey: _apiKey!,
        whiteModel: _white!,
        blackModel: _black!,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chess Arena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Watch two OpenRouter models battle it out.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _sideCard(
              label: 'White',
              model: _white,
              onTap: () => _pickModel(forWhite: true),
            ),
            const SizedBox(height: 12),
            _sideCard(
              label: 'Black',
              model: _black,
              onTap: () => _pickModel(forWhite: false),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start game'),
              onPressed: _start,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideCard({
    required String label,
    required AiModel? model,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(label[0])),
        title: Text(label),
        subtitle: Text(model?.name ?? 'Tap to pick a model'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
