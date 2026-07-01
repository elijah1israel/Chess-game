import 'package:chess/chess.dart' as ch;

import 'openrouter_service.dart';

/// Result of asking a model for a move.
class AiMoveResult {
  final String san;
  final String uci;
  final String rawResponse;
  final bool wasFallback;

  const AiMoveResult({
    required this.san,
    required this.uci,
    required this.rawResponse,
    required this.wasFallback,
  });
}

class ChessAiPlayer {
  final OpenRouterService service;
  final String modelId;

  ChessAiPlayer({required this.service, required this.modelId});

  Future<AiMoveResult> chooseMove(ch.Chess game) async {
    final fen = game.fen;
    final sideToMove = game.turn == ch.Color.WHITE ? 'White' : 'Black';

    final legalMoves = game.generate_moves();
    if (legalMoves.isEmpty) {
      throw StateError('No legal moves.');
    }

    final sanMoves = <String>[];
    final uciMoves = <String>[];
    final byUci = <String, ch.Move>{};
    final bySan = <String, ch.Move>{};
    for (final m in legalMoves) {
      final san = game.move_to_san(m);
      final uci = _uciFor(m);
      sanMoves.add(san);
      uciMoves.add(uci);
      byUci[uci] = m;
      bySan[san] = m;
    }

    final legalList = List.generate(
      sanMoves.length,
      (i) => '${sanMoves[i]} (${uciMoves[i]})',
    ).join(', ');

    final systemPrompt =
        'You are a chess engine. Reply with EXACTLY ONE move and nothing else. '
        'No commentary, no punctuation beyond the move itself. Prefer UCI notation like e2e4 or g1f3, '
        'or SAN like Nf3. The move MUST be one of the legal moves provided.';

    final userPrompt = 'You play $sideToMove.\n'
        'Position (FEN): $fen\n'
        'Legal moves: $legalList\n'
        'Reply with one legal move.';

    String raw = '';
    ch.Move? picked;
    for (var attempt = 0; attempt < 2 && picked == null; attempt++) {
      raw = await service.chat(
        model: modelId,
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        temperature: attempt == 0 ? 0.2 : 0.0,
        maxTokens: 16,
      );
      picked = _parseMove(raw, bySan: bySan, byUci: byUci);
    }

    var fallback = false;
    if (picked == null) {
      picked = legalMoves.first;
      fallback = true;
    }

    final chosenSan = game.move_to_san(picked);
    final chosenUci = _uciFor(picked);
    final promo = picked.promotion;
    game.move({
      'from': ch.Chess.algebraic(picked.from),
      'to': ch.Chess.algebraic(picked.to),
      if (promo != null) 'promotion': _pieceLetter(promo),
    });

    return AiMoveResult(
      san: chosenSan,
      uci: chosenUci,
      rawResponse: raw,
      wasFallback: fallback,
    );
  }

  static String _uciFor(ch.Move m) {
    final from = ch.Chess.algebraic(m.from);
    final to = ch.Chess.algebraic(m.to);
    final promo = m.promotion == null
        ? ''
        : _pieceLetter(m.promotion!);
    return '$from$to$promo';
  }

  static String _pieceLetter(ch.PieceType p) {
    switch (p) {
      case ch.PieceType.QUEEN:
        return 'q';
      case ch.PieceType.ROOK:
        return 'r';
      case ch.PieceType.BISHOP:
        return 'b';
      case ch.PieceType.KNIGHT:
        return 'n';
      default:
        return '';
    }
  }

  static ch.Move? _parseMove(
    String raw, {
    required Map<String, ch.Move> bySan,
    required Map<String, ch.Move> byUci,
  }) {
    if (raw.isEmpty) return null;
    final text = raw.trim().replaceAll(RegExp(r'[`*_]'), '');

    // Try each whitespace-separated token
    for (final tokenRaw in text.split(RegExp(r'\s+'))) {
      final token = tokenRaw.replaceAll(RegExp(r'[.,;:!?"\']+$'), '').trim();
      if (token.isEmpty) continue;

      // Exact UCI match
      final uciCandidate = token.toLowerCase();
      if (byUci.containsKey(uciCandidate)) return byUci[uciCandidate];

      // Exact SAN match
      if (bySan.containsKey(token)) return bySan[token];

      // SAN without check/mate suffix
      final stripped = token.replaceAll(RegExp(r'[+#]'), '');
      if (bySan.containsKey(stripped)) return bySan[stripped];

      // UCI-like inside longer token e.g. "e2e4."
      final uciMatch =
          RegExp(r'([a-h][1-8][a-h][1-8][qrbn]?)').firstMatch(uciCandidate);
      if (uciMatch != null && byUci.containsKey(uciMatch.group(1))) {
        return byUci[uciMatch.group(1)];
      }
    }
    return null;
  }
}
