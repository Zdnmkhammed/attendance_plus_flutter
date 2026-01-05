import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class TetrisScreen extends StatefulWidget {
  const TetrisScreen({super.key});

  @override
  State<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends State<TetrisScreen> {
  static const int rows = 20;
  static const int cols = 10;

  late List<List<int>> board;

  final Random _rand = Random();
  Timer? _timer;
  bool _running = false;
  int _score = 0;

  late _Piece _current;
  late _Piece _next; // следующая фигура

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    board = List.generate(rows, (_) => List.filled(cols, 0));
    _score = 0;
    _current = _Piece.random(cols, _rand);
    _next = _Piece.random(cols, _rand);
  }

  Duration get _currentTick {
    if (_score < 500) {
      return const Duration(milliseconds: 380);
    } else if (_score < 1500) {
      return const Duration(milliseconds: 260);
    } else if (_score < 3000) {
      return const Duration(milliseconds: 190);
    } else {
      return const Duration(milliseconds: 130);
    }
  }

  void _startGame() {
    _timer?.cancel();
    _running = true;
    _timer = Timer.periodic(_currentTick, (_) => _tickDown());
    setState(() {});
  }

  void _stopGame() {
    _timer?.cancel();
    _running = false;
    setState(() {});
  }

  void _spawnNextPiece() {
    _current = _next;
    _current = _current.withStartX(cols);
    _next = _Piece.random(cols, _rand);
    if (_collides(_current)) {
      // game over
      _stopGame();
      _resetBoard();
    }
  }

  bool _collides(_Piece p) {
    for (final cell in p.cells) {
      final x = cell.$1;
      final y = cell.$2;
      if (x < 0 || x >= cols || y >= rows) return true;
      if (y >= 0 && board[y][x] != 0) return true;
    }
    return false;
  }

  void _mergePiece() {
    for (final cell in _current.cells) {
      final x = cell.$1;
      final y = cell.$2;
      if (y >= 0 && y < rows && x >= 0 && x < cols) {
        board[y][x] = _current.colorIndex;
      }
    }
  }

  void _clearLines() {
    int cleared = 0;
    for (int y = rows - 1; y >= 0; y--) {
      if (board[y].every((v) => v != 0)) {
        board.removeAt(y);
        board.insert(0, List.filled(cols, 0));
        cleared++;
        y++;
      }
    }
    if (cleared > 0) {
      _score += cleared * 100;

      if (_running) {
        _timer?.cancel();
        _timer = Timer.periodic(_currentTick, (_) => _tickDown());
      }
    }
  }

  void _tickDown() {
    if (!_running) return;
    final moved = _current.moved(0, 1);
    if (_collides(moved)) {
      _mergePiece();
      _clearLines();
      _spawnNextPiece();
    } else {
      _current = moved;
    }
    setState(() {});
  }

  void _moveHorizontal(int dx) {
    if (!_running) return;
    final moved = _current.moved(dx, 0);
    if (!_collides(moved)) {
      setState(() {
        _current = moved;
      });
    }
  }

  void _softDrop() {
    if (!_running) return;
    final moved = _current.moved(0, 1);
    if (!_collides(moved)) {
      setState(() {
        _current = moved;
      });
    }
  }

  void _rotate() {
    if (!_running) return;
    final rotated = _current.rotated();
    if (!_collides(rotated)) {
      setState(() {
        _current = rotated;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _colorFor(int v) {
    switch (v) {
      case 1:
        return Colors.cyan;
      case 2:
        return Colors.yellow;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.green;
      case 5:
        return Colors.red;
      case 6:
        return Colors.blue;
      case 7:
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tempBoard =
        List.generate(rows, (y) => List<int>.from(board[y]));
    for (final cell in _current.cells) {
      final x = cell.$1;
      final y = cell.$2;
      if (y >= 0 && y < rows && x >= 0 && x < cols) {
        tempBoard[y][x] = _current.colorIndex;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text('Tetris'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // превью следующей фигуры
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'NEXT',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    _NextPiecePreview(piece: _next, colorFor: _colorFor),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: cols / rows,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                    ),
                    itemCount: rows * cols,
                    itemBuilder: (_, index) {
                      final x = index % cols;
                      final y = index ~/ cols;
                      final v = tempBoard[y][x];
                      return Container(
                        margin: const EdgeInsets.all(0.5),
                        decoration: BoxDecoration(
                          color: v == 0
                              ? Colors.grey.shade900
                              : _colorFor(v),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Центральная круглая кнопка START / Rotate
          GestureDetector(
            onTap: _running ? _rotate : _startGame,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _running
                    ? Colors.deepPurple
                    : Colors.greenAccent.shade400,
                boxShadow: [
                  BoxShadow(
                    color: (_running
                            ? Colors.deepPurple
                            : Colors.greenAccent.shade400)
                        .withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _running ? 'ROTATE' : 'START',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _running ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Нижние кнопки: влево, вниз, вправо
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _moveHorizontal(-1),
                  icon: const Icon(Icons.arrow_left),
                  color: Colors.white,
                  iconSize: 32,
                ),
                IconButton(
                  onPressed: _softDrop,
                  icon: const Icon(Icons.arrow_downward),
                  color: Colors.white,
                  iconSize: 32,
                ),
                IconButton(
                  onPressed: () => _moveHorizontal(1),
                  icon: const Icon(Icons.arrow_right),
                  color: Colors.white,
                  iconSize: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Превью следующей фигуры в маленьком квадратике 4x4
class _NextPiecePreview extends StatelessWidget {
  final _Piece piece;
  final Color Function(int) colorFor;

  const _NextPiecePreview({
    required this.piece,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final shape = piece.shape;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
        ),
        itemCount: 16,
        itemBuilder: (_, index) {
          final x = index % 4;
          final y = index ~/ 4;
          final v = shape[y][x];
          return Container(
            margin: const EdgeInsets.all(0.5),
            decoration: BoxDecoration(
              color: v == 0 ? Colors.black : colorFor(piece.colorIndex),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      ),
    );
  }
}

// ====== модель фигуры ======

class _Piece {
  final List<List<int>> shape; // 4x4 матрица 0/1
  final int colorIndex;
  final int x; // позиция левого верхнего угла
  final int y;

  _Piece({
    required this.shape,
    required this.colorIndex,
    required this.x,
    required this.y,
  });

  List<(int, int)> get cells {
    final List<(int, int)> res = [];
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] != 0) {
          res.add((x + c, y + r));
        }
      }
    }
    return res;
  }

  _Piece moved(int dx, int dy) => _Piece(
        shape: shape,
        colorIndex: colorIndex,
        x: x + dx,
        y: y + dy,
      );

  _Piece rotated() {
    final n = shape.length;
    final rotated = List.generate(
      n,
      (_) => List.filled(n, 0),
    );
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        rotated[c][n - 1 - r] = shape[r][c];
      }
    }
    return _Piece(
      shape: rotated,
      colorIndex: colorIndex,
      x: x,
      y: y,
    );
  }

  _Piece withStartX(int cols) => _Piece(
        shape: shape,
        colorIndex: colorIndex,
        x: (cols ~/ 2) - 2,
        y: -1,
      );

  static final List<List<List<int>>> _shapes = [
    // I
    [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ],
    // O
    [
      [0, 0, 0, 0],
      [0, 2, 2, 0],
      [0, 2, 2, 0],
      [0, 0, 0, 0],
    ],
    // T
    [
      [0, 0, 0, 0],
      [0, 3, 0, 0],
      [3, 3, 3, 0],
      [0, 0, 0, 0],
    ],
    // S
    [
      [0, 0, 0, 0],
      [0, 4, 4, 0],
      [4, 4, 0, 0],
      [0, 0, 0, 0],
    ],
    // Z
    [
      [0, 0, 0, 0],
      [5, 5, 0, 0],
      [0, 5, 5, 0],
      [0, 0, 0, 0],
    ],
    // J
    [
      [0, 0, 0, 0],
      [6, 0, 0, 0],
      [6, 6, 6, 0],
      [0, 0, 0, 0],
    ],
    // L
    [
      [0, 0, 0, 0],
      [0, 0, 7, 0],
      [7, 7, 7, 0],
      [0, 0, 0, 0],
    ],
  ];

  static _Piece random(int cols, Random rand) {
    final idx = rand.nextInt(_shapes.length);
    final shape = _shapes[idx];
    final colorIndex = idx + 1;
    final startX = (cols ~/ 2) - 2;
    return _Piece(
      shape: shape,
      colorIndex: colorIndex,
      x: startX,
      y: -1,
    );
  }
}
