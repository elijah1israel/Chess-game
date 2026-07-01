import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

/// A custom, dependency-free chess board renderer.
///
/// Renders from a FEN string. Highlights the last move if given.
class ChessBoardWidget extends StatelessWidget {
  final String fen;
  final String? lastMoveFromSquare; // e.g. "e2"
  final String? lastMoveToSquare;   // e.g. "e4"
  final bool flipped;

  const ChessBoardWidget({
    super.key,
    required this.fen,
    this.lastMoveFromSquare,
    this.lastMoveToSquare,
    this.flipped = false,
  });

  // Board colors (lichess brown palette)
  static const _light = Color(0xFFF0D9B5);
  static const _dark = Color(0xFFB58863);
  static const _lastMoveOverlay = Color(0x88FFF176); // amber transparent
  static const _frame = Color(0xFF2E2A24);
  static const _coordDark = Color(0xFF6B4C2A);
  static const _coordLight = Color(0xFFEED9B8);

  static const _pieceGlyphs = {
    'K': '♔', 'Q': '♕', 'R': '♖',
    'B': '♗', 'N': '♘', 'P': '♙',
    'k': '♚', 'q': '♛', 'r': '♜',
    'b': '♝', 'n': '♞', 'p': '♟',
  };

  @override
  Widget build(BuildContext context) {
    final board = _parseFenBoard(fen);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final tile = side / 8;
        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: _frame,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Column(
              children: List.generate(8, (row) {
                final rank = flipped ? row : 7 - row;
                return Expanded(
                  child: Row(
                    children: List.generate(8, (col) {
                      final file = flipped ? 7 - col : col;
                      final isDark = (rank + file).isOdd == false;
                      final baseColor = isDark ? _dark : _light;
                      final square = _squareName(file, rank);
                      final highlighted = square == lastMoveFromSquare ||
                          square == lastMoveToSquare;
                      final piece = board[rank][file];
                      final coordColor =
                          isDark ? _coordLight : _coordDark;

                      return Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: baseColor),
                            if (highlighted)
                              Container(color: _lastMoveOverlay),
                            if (col == 0)
                              Positioned(
                                left: 3,
                                top: 2,
                                child: Text(
                                  '${rank + 1}',
                                  style: TextStyle(
                                    fontSize: tile * 0.18,
                                    fontWeight: FontWeight.w700,
                                    color: coordColor,
                                  ),
                                ),
                              ),
                            if (row == 7)
                              Positioned(
                                right: 4,
                                bottom: 1,
                                child: Text(
                                  String.fromCharCode(
                                      'a'.codeUnitAt(0) + file),
                                  style: TextStyle(
                                    fontSize: tile * 0.18,
                                    fontWeight: FontWeight.w700,
                                    color: coordColor,
                                  ),
                                ),
                              ),
                            if (piece != null)
                              Center(child: _piece(piece, tile)),
                          ],
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _piece(String piece, double tile) {
    final glyph = _pieceGlyphs[piece] ?? '';
    final isWhite = piece == piece.toUpperCase();
    final fill = isWhite ? Colors.white : const Color(0xFF1A1A1A);
    final stroke = isWhite ? const Color(0xFF1A1A1A) : Colors.white;
    return SizedBox(
      width: tile,
      height: tile,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft shadow for depth
          Text(
            glyph,
            style: TextStyle(
              fontSize: tile * 0.82,
              height: 1.0,
              color: const Color(0x66000000),
              shadows: const [
                Shadow(blurRadius: 8, offset: Offset(0, 3), color: Color(0x55000000)),
              ],
            ),
          ),
          // Outline pass (offset copies)
          for (final dx in const [-1.2, 1.2])
            for (final dy in const [-1.2, 1.2])
              Transform.translate(
                offset: Offset(dx, dy),
                child: Text(
                  glyph,
                  style: TextStyle(
                    fontSize: tile * 0.82,
                    height: 1.0,
                    color: stroke,
                  ),
                ),
              ),
          // Main fill
          Text(
            glyph,
            style: TextStyle(
              fontSize: tile * 0.82,
              height: 1.0,
              color: fill,
            ),
          ),
        ],
      ),
    );
  }

  static String _squareName(int file, int rank) =>
      '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';

  /// Returns board[rank][file] with rank 0 = rank 1, file 0 = 'a'.
  static List<List<String?>> _parseFenBoard(String fen) {
    final rows = fen.split(' ').first.split('/');
    final board = List.generate(8, (_) => List<String?>.filled(8, null));
    for (var i = 0; i < 8; i++) {
      final rank = 7 - i; // FEN starts at rank 8
      var file = 0;
      for (final c in rows[i].split('')) {
        final n = int.tryParse(c);
        if (n != null) {
          file += n;
        } else {
          if (file < 8) board[rank][file] = c;
          file++;
        }
      }
    }
    return board;
  }
}

/// Convenience helpers to pull the last move out of a ch.Chess history.
class LastMove {
  final String from;
  final String to;
  const LastMove(this.from, this.to);

  static LastMove? fromGame(ch.Chess game) {
    final history = game.getHistory({'verbose': true});
    if (history is List && history.isNotEmpty) {
      final last = history.last;
      if (last is Map) {
        final from = last['from']?.toString();
        final to = last['to']?.toString();
        if (from != null && to != null) return LastMove(from, to);
      }
    }
    return null;
  }
}
