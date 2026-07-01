import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import '../models/ai_model.dart';
import '../services/chess_ai_player.dart';
import '../services/openrouter_service.dart';

class GameScreen extends StatefulWidget {
  final String apiKey;
  final AiModel whiteModel;
  final AiModel blackModel;

  const GameScreen({
    super.key,
    required this.apiKey,
    required this.whiteModel,
    required this.blackModel,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _MoveEntry {
  final int moveNumber;
  final String san;
  final String uci;
  final bool white;
  final bool fallback;
  final String modelName;

  _MoveEntry({
    required this.moveNumber,
    required this.san,
    required this.uci,
    required this.white,
    required this.fallback,
    required this.modelName,
  });
}

class _GameScreenState extends State<GameScreen> {
  late final OpenRouterService _service =
      OpenRouterService(widget.apiKey);
  late final ChessAiPlayer _whitePlayer = ChessAiPlayer(
    service: _service,
    modelId: widget.whiteModel.id,
  );
  late final ChessAiPlayer _blackPlayer = ChessAiPlayer(
    service: _service,
    modelId: widget.blackModel.id,
  );

  final ch.Chess _game = ch.Chess();
  final ChessBoardController _boardController = ChessBoardController();
  final List<_MoveEntry> _log = [];
  final ScrollController _logScroll = ScrollController();

  bool _running = false;
  bool _paused = false;
  String? _error;
  String _status = 'Ready.';

  @override
  void initState() {
    super.initState();
    _boardController.loadFen(_game.fen);
  }

  @override
  void dispose() {
    _service.close();
    _boardController.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _startLoop() async {
    if (_running) return;
    setState(() {
      _running = true;
      _paused = false;
      _error = null;
    });
    try {
      while (_running && !_paused && !_game.game_over) {
        final whiteToMove = _game.turn == ch.Color.WHITE;
        final player = whiteToMove ? _whitePlayer : _blackPlayer;
        final modelName =
            whiteToMove ? widget.whiteModel.name : widget.blackModel.name;

        setState(() => _status = '$modelName thinking…');

        final result = await player.chooseMove(_game);

        final moveNumber = (_log.length ~/ 2) + 1;
        _log.add(_MoveEntry(
          moveNumber: moveNumber,
          san: result.san,
          uci: result.uci,
          white: whiteToMove,
          fallback: result.wasFallback,
          modelName: modelName,
        ));
        _boardController.loadFen(_game.fen);
        if (mounted) {
          setState(() => _status = _liveStatus());
        }
        _scrollLogToEnd();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _status = _liveStatus();
        });
      }
    }
  }

  void _pause() {
    setState(() {
      _paused = true;
      _running = false;
    });
  }

  void _reset() {
    setState(() {
      _game.reset();
      _boardController.loadFen(_game.fen);
      _log.clear();
      _error = null;
      _paused = false;
      _running = false;
      _status = 'Ready.';
    });
  }

  String _liveStatus() {
    if (_game.in_checkmate) {
      final loser = _game.turn == ch.Color.WHITE ? 'White' : 'Black';
      final winner = loser == 'White' ? 'Black' : 'White';
      return 'Checkmate. $winner wins.';
    }
    if (_game.in_stalemate) return 'Stalemate. Draw.';
    if (_game.in_threefold_repetition) return 'Draw by repetition.';
    if (_game.insufficient_material) return 'Draw: insufficient material.';
    if (_game.in_draw) return 'Draw.';
    if (_paused) return 'Paused.';
    if (_running) return 'Running…';
    return 'Ready.';
  }

  void _scrollLogToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameOver = _game.game_over;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset',
            onPressed: _running ? null : _reset,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _playerBadge('Black', widget.blackModel, _game.turn == ch.Color.BLACK),
            const SizedBox(height: 8),
            Center(
              child: ChessBoard(
                controller: _boardController,
                boardColor: BoardColor.brown,
                boardOrientation: PlayerColor.white,
                enableUserMoves: false,
              ),
            ),
            const SizedBox(height: 8),
            _playerBadge('White', widget.whiteModel, _game.turn == ch.Color.WHITE),
            const SizedBox(height: 8),
            Text(_status, textAlign: TextAlign.center),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause' : (gameOver ? 'Game over' : 'Play')),
                  onPressed: gameOver
                      ? null
                      : (_running ? _pause : _startLoop),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _moveLog()),
          ],
        ),
      ),
    );
  }

  Widget _playerBadge(String label, AiModel model, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              model.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (active)
            const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _moveLog() {
    if (_log.isEmpty) {
      return const Center(
        child: Text('No moves yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Card(
      child: ListView.builder(
        controller: _logScroll,
        itemCount: _log.length,
        itemBuilder: (context, i) {
          final e = _log[i];
          final prefix = e.white ? '${e.moveNumber}.' : '${e.moveNumber}...';
          return ListTile(
            dense: true,
            leading: Text(prefix),
            title: Text('${e.san}  (${e.uci})'),
            subtitle: Text(e.modelName),
            trailing: e.fallback
                ? const Tooltip(
                    message: 'Model output was invalid; fallback move used.',
                    child: Icon(Icons.warning_amber, color: Colors.orange),
                  )
                : null,
          );
        },
      ),
    );
  }
}
