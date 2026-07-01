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

    final history = _formatHistory(game);
    final inCheck = game.in_check ? ' You are in CHECK.' : '';

    const systemPrompt =
        'You are a strong chess player and you play to WIN. Follow these rules:\n'
        '1. Look for checks, captures, and threats before quiet moves.\n'
        '2. Do NOT repeat positions or shuffle pieces back and forth — that leads to draws you can avoid.\n'
        '3. Weigh king safety, piece activity, and pawn structure.\n'
        '4. You may think briefly, but end your reply with a single final line:\n'
        '   MOVE: <move>\n'
        '   where <move> is one of the legal moves in UCI (e2e4, g1f3, e7e8q) or SAN (Nf3, Qxh7#) form.\n'
        '   The line starting with MOVE: is the ONLY thing I will parse.';

    final userPrompt = 'You play $sideToMove.$inCheck\n'
        'Move history so far: $history\n'
        'Current position (FEN): $fen\n'
        'Legal moves: $legalList\n\n'
        'Briefly evaluate the position (2–4 short lines), then output your chosen move on a final '
        '"MOVE: <move>" line. Choose the strongest move you can find; do not settle for a draw '
        'when winning chances exist.';

    String raw = '';
    ch.Move? picked;
    for (var attempt = 0; attempt < 2 && picked == null; attempt++) {
      raw = await service.chat(
        model: modelId,
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        temperature: attempt == 0 ? 0.4 : 0.1,
        maxTokens: 400,
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

  /// Renders the game so far as "1. e4 e5 2. Nf3 Nc6 ..." for the prompt.
  /// Caps at the last 40 plies so the prompt doesn't get gigantic.
  static String _formatHistory(ch.Chess game) {
    final history = List<String>.from(game.getHistory() as Iterable);
    if (history.isEmpty) return '(no moves yet — opening position)';
    final tail = history.length > 40
        ? history.sublist(history.length - 40)
        : history;
    final leadingPly = history.length - tail.length;
    final buf = StringBuffer();
    for (var i = 0; i < tail.length; i++) {
      final ply = leadingPly + i;
      if (ply.isEven) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write('${(ply ~/ 2) + 1}.');
      }
      buf.write(' ${tail[i]}');
    }
    return buf.toString();
  }

  static ch.Move? _parseMove(
    String raw, {
    required Map<String, ch.Move> bySan,
    required Map<String, ch.Move> byUci,
  }) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[`*_]'), '');

    // Prefer the last "MOVE: ..." line, since the prompt tells the model to
    // put its final choice there after any reasoning.
    final moveLine = RegExp(
      r'MOVE\s*[:\-]\s*([^\n\r]+)',
      caseSensitive: false,
    ).allMatches(cleaned).lastOrNull;
    final scanText = moveLine != null ? moveLine.group(1)! : cleaned.trim();

    // Try each whitespace-separated token
    for (final tokenRaw in scanText.split(RegExp(r'\s+'))) {
      final token = tokenRaw.replaceAll(RegExp("[.,;:!?\"']+\$"), '').trim();
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
