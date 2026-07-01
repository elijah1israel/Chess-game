import 'package:flutter/material.dart';

import '../models/ai_model.dart';
import '../services/openrouter_service.dart';

class ModelPickerScreen extends StatefulWidget {
  final OpenRouterService service;
  final String title;
  final String? initialSelectedId;

  const ModelPickerScreen({
    super.key,
    required this.service,
    required this.title,
    this.initialSelectedId,
  });

  @override
  State<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends State<ModelPickerScreen> {
  late Future<List<AiModel>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.service.listModels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter models',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AiModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error loading models:\n${snap.error}'),
                  );
                }
                final all = snap.data ?? const [];
                final filtered = _query.isEmpty
                    ? all
                    : all
                        .where((m) =>
                            m.id.toLowerCase().contains(_query) ||
                            m.name.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No models match.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final m = filtered[i];
                    final selected = m.id == widget.initialSelectedId;
                    return ListTile(
                      title: Text(m.name),
                      subtitle: Text(m.id),
                      trailing: selected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () => Navigator.of(context).pop(m),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
