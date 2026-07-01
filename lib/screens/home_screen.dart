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
    final scheme = Theme.of(context).colorScheme;
    final hasKey = _apiKey != null && _apiKey!.isNotEmpty;
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '♞',
                    style: TextStyle(
                      fontSize: 46,
                      color: scheme.primary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pick two models and\nwatch them battle.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sideCard(
                label: 'White',
                model: _white,
                onTap: () => _pickModel(forWhite: true),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'vs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sideCard(
                label: 'Black',
                model: _black,
                onTap: () => _pickModel(forWhite: false),
              ),
              if (!hasKey)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.key, color: scheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No OpenRouter key set. Open settings to add one.',
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Start game',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: _start,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideCard({
    required String label,
    required AiModel? model,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: label == 'White'
                      ? Colors.white
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: Text(
                  '♚',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1,
                    color: label == 'White'
                        ? const Color(0xFF1A1A1A)
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model?.name ?? 'Tap to pick a model',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: model == null
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontStyle:
                            model == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    if (model?.id != null)
                      Text(
                        model!.id,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
