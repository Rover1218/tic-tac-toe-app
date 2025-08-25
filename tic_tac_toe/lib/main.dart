import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Reactive theme controls
final ValueNotifier<Color> seedColorNotifier =
    ValueNotifier<Color>(const Color(0xFF0BA5A4));
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

void main() => runApp(const TicTacToeApp());

enum GameMode { twoPlayer, computer }

enum Difficulty { easy, medium, hard }

class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: seedColorNotifier,
      builder: (context, seed, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, __) {
            return MaterialApp(
              title: 'Tic Tac Toe',
              themeMode: mode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
                useMaterial3: true,
              ),
              home: const TicTacToe(),
            );
          },
        );
      },
    );
  }
}

// Small colored dot used in theme color chips
class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
    );
  }
}

class TicTacToe extends StatefulWidget {
  const TicTacToe({super.key});

  @override
  State<TicTacToe> createState() => _TicTacToeState();
}

class _TicTacToeState extends State<TicTacToe> with TickerProviderStateMixin {
  List<String> board = List.filled(9, '');
  String currentPlayer = 'X';
  String result = '';
  bool gameOver = false;
  late AnimationController _controller;
  int xScore = 0;
  int oScore = 0;
  int draws = 0;
  late AnimationController _pulseController;
  late AnimationController _celebrationController;
  late AnimationController _sheetAnimationController;
  late AnimationController _shimmerController;
  late ConfettiController _confettiController;
  bool isLoading = true;
  List<Color> get playerColors => [
    Theme.of(context).colorScheme.primary, // Use theme primary for X
    Theme.of(context).colorScheme.secondary, // Use theme secondary for O
  ];
  GameMode gameMode = GameMode.twoPlayer;
  Difficulty difficulty = Difficulty.medium;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isSoundEnabled = true; // Add this line
  final List<int> _moveHistory = []; // track moves for undo
  List<int>? _winningLine; // track winning indices
  bool _startWithX = true; // starting player selector
  // Turn ownership and input/AI state
  String _humanSymbol = 'X';
  String _computerSymbol = 'O';
  bool _aiThinking = false;
  bool _isHandlingTap = false; // prevent multi-touch double moves
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _sheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Add initial loading animation
    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        isLoading = false;
      });
    });
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _celebrationController.dispose();
    _sheetAnimationController.dispose();
    _shimmerController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String soundType) async {
    if (!isSoundEnabled) return; // Add this check

    try {
      await _audioPlayer.stop();

      // Remove the initial delay for move sound
      if (soundType == 'move') {
        await _audioPlayer.play(AssetSource('sounds/move.mp3'));
      } else {
        // Keep delays for win and draw sounds
        await Future.delayed(
            Duration(milliseconds: soundType == 'win' ? 100 : 50));
        await _audioPlayer.play(AssetSource('sounds/$soundType.mp3'));
      }
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _startCountdownTimer() {
    _countdownSeconds = 5;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownSeconds--;
      });
      if (_countdownSeconds <= 0) {
        timer.cancel();
        resetGame();
      }
    });
  }

  void resetGame() {
    _countdownTimer?.cancel();
    setState(() {
      board = List.filled(9, '');
      currentPlayer = _startWithX ? 'X' : 'O';
      result = '';
      gameOver = false;
      _winningLine = null;
      _moveHistory.clear();
      _countdownSeconds = 5;
    });
    _controller.reset();
    _celebrationController.reset();
    _confettiController.stop();
    if (gameMode == GameMode.computer && currentPlayer == _computerSymbol) {
      makeComputerMove();
    }
  }

  void resetStats() {
    setState(() {
      xScore = 0;
      oScore = 0;
      draws = 0; // Add this line
    });
  }

  void handleTap(int index, {bool byAI = false}) {
    if (gameOver || board[index] != '') return;
    // Block when it's not the human's turn or AI is thinking (unless move is by AI)
    if (!byAI && gameMode == GameMode.computer) {
      if (_aiThinking || currentPlayer != _humanSymbol) return;
    }
    // Prevent multi-touch / rapid double taps
    if (_isHandlingTap) return;
    _isHandlingTap = true;
    try {
      // Play move sound immediately before state update
      _playSound('move');

      setState(() {
        board[index] = currentPlayer;
        _controller.forward(from: 0.0);
        _moveHistory.add(index);

        if (checkWinner(currentPlayer)) {
          _celebrationController.forward(from: 0.0);
          _confettiController.play();
          Future.delayed(const Duration(milliseconds: 100), () {
            _playSound('win');
          });
          result = '$currentPlayer Wins!';
          gameOver = true;
          if (currentPlayer == 'X') {
            xScore++;
          } else {
            oScore++;
          }
          // Start countdown timer
          _startCountdownTimer();
        } else if (!board.contains('')) {
          result = 'It\'s a Draw!';
          gameOver = true;
          draws++;
          Future.delayed(const Duration(milliseconds: 50), () {
            _playSound('draw');
          });
          // Start countdown timer
          _startCountdownTimer();
        } else {
          currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
          if (gameMode == GameMode.computer && currentPlayer == _computerSymbol) {
            makeComputerMove();
          }
        }
      });
    } finally {
      _isHandlingTap = false;
    }
  }


  void makeComputerMove() {
    if (gameOver || currentPlayer != _computerSymbol || _aiThinking) return;

    int move;
    switch (difficulty) {
      case Difficulty.easy:
        move = getRandomMove();
        break;
      case Difficulty.medium:
        // Faster medium: 60% depth-capped best move (shallower search), 40% random
        move = math.Random().nextDouble() < 0.6
            ? getBestMoveCapped(3)
            : getRandomMove();
        break;
      case Difficulty.hard:
        move = getBestMove();
        break;
    }
    _aiThinking = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      _aiThinking = false;
      handleTap(move, byAI: true);
    });
  }

  int getRandomMove() {
    List<int> availableMoves = [];
    for (int i = 0; i < board.length; i++) {
      if (board[i] == '') availableMoves.add(i);
    }
    return availableMoves[math.Random().nextInt(availableMoves.length)];
  }

  int getBestMove() {
    int bestScore = -1000;
    int bestMove = 0;

    for (int i = 0; i < board.length; i++) {
      if (board[i] == '') {
        board[i] = _computerSymbol;
        int score = minimax(board, 0, false, -1000, 1000, null, _computerSymbol);
        board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }
    return bestMove;
  }

  int getBestMoveCapped(int maxDepth) {
    int bestScore = -1000;
    int bestMove = 0;

    for (int i = 0; i < board.length; i++) {
      if (board[i] == '') {
        board[i] = _computerSymbol;
        int score = minimax(board, 0, false, -1000, 1000, maxDepth, _computerSymbol);
        board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }
    return bestMove;
  }

  // Pure board evaluation helpers for AI (do not touch UI state)
  bool _hasWinnerOn(List<String> b, String player) {
    const patterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final p in patterns) {
      if (p.every((i) => b[i] == player)) return true;
    }
    return false;
  }

  String _gameResultOn(List<String> b) {
    if (_hasWinnerOn(b, 'X')) return 'X';
    if (_hasWinnerOn(b, 'O')) return 'O';
    if (!b.contains('')) return 'draw';
    return '';
  }

  int minimax(List<String> board, int depth, bool isMaximizing, int alpha,
      int beta, int? maxDepth, String aiSymbol) {
    String result = _gameResultOn(board);
    // Depth cap for faster medium difficulty
    if (maxDepth != null && depth >= maxDepth) {
      // Simple evaluation at cap: immediate win/loss detection, else neutral
      if (result == aiSymbol) return 10 - depth;
      if (result.isNotEmpty && result != 'draw' && result != aiSymbol) {
        return depth - 10;
      }
      return 0;
    }
    if (result != '') {
      if (result == aiSymbol) return 10 - depth;
      if (result.isNotEmpty && result != 'draw' && result != aiSymbol) {
        return depth - 10;
      }
      return 0;
    }

    final opponent = aiSymbol == 'X' ? 'O' : 'X';
    if (isMaximizing) {
      int maxEval = -1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == '') {
          board[i] = aiSymbol;
          int eval = minimax(board, depth + 1, false, alpha, beta, maxDepth, aiSymbol);
          board[i] = '';
          maxEval = math.max(maxEval, eval);
          alpha = math.max(alpha, eval);
          if (beta <= alpha) {
            break; // Alpha-beta pruning
          }
        }
      }
      return maxEval;
    } else {
      int minEval = 1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == '') {
          board[i] = opponent;
          int eval = minimax(board, depth + 1, true, alpha, beta, maxDepth, aiSymbol);
          board[i] = '';
          minEval = math.min(minEval, eval);
          beta = math.min(beta, eval);
          if (beta <= alpha) {
            break; // Alpha-beta pruning
          }
        }
      }
      return minEval;
    }
  }

  String checkGameResult() {
    if (checkWinner('X')) return 'X';
    if (checkWinner('O')) return 'O';
    if (!board.contains('')) return 'draw';
    return '';
  }

  bool checkWinner(String player) {
    // Winning combinations
    List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
      [0, 4, 8], [2, 4, 6], // Diagonals
    ];

    for (var pattern in winPatterns) {
      if (pattern.every((index) => board[index] == player)) {
        _winningLine = pattern;
        return true;
      }
    }
    return false;
  }

  Widget _buildGridCell(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _winningLine?.contains(index) == true
            ? (board[index] == 'X' ? playerColors[0] : playerColors[1])
                .withOpacity(0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _winningLine?.contains(index) == true
              ? (board[index] == 'X' ? playerColors[0] : playerColors[1])
              : board[index].isNotEmpty
                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.35)
                  : Colors.grey.shade300,
          width: _winningLine?.contains(index) == true ? 3 : 2,
        ),
        boxShadow: [
          // Lighter shadows for better perf (especially on web/low-end)
          BoxShadow(
            color: (_winningLine?.contains(index) == true
                    ? (board[index] == 'X' ? playerColors[0] : playerColors[1])
                        .withOpacity(0.18)
                    : Colors.black.withOpacity(0.02)),
            blurRadius: _winningLine?.contains(index) == true ? 10 : 6,
            spreadRadius: _winningLine?.contains(index) == true ? 1 : 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          padding: const EdgeInsets.all(15),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(curve: Curves.easeOutBack, parent: animation),
                child: child,
              ),
              child: Text(
                board[index],
                key: ValueKey(board[index]),
                style: TextStyle(
                  fontSize: board[index].isEmpty ? 0 : 60,
                  fontWeight: FontWeight.w700,
                  color: board[index].isEmpty
                      ? Colors.transparent
                      : Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    // Slightly different bases by theme for better separation in light mode
    final Color unselectedBase =
        isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
    // Selected background lighter in light mode, stronger in dark mode
    final Color bg = isSelected
        ? color.withValues(alpha: isDark ? 0.15 : 0.06)
        : unselectedBase;
    final Color border = isSelected ? color : scheme.outlineVariant;
    // In light mode keep text readable (onSurface). In dark, colored text is fine.
    final Color fg = isSelected
        ? (isDark ? color : scheme.onSurface)
        : scheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: fg,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(Difficulty diff,
      {required bool isSelected, required VoidCallback onTap}) {
    final colors = {
      Difficulty.easy: Colors.green,
      Difficulty.medium: Colors.orange,
      Difficulty.hard: Colors.red,
    };
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final base = isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
    final selColor = colors[diff]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? selColor.withValues(alpha: isDark ? 0.15 : 0.06)
                : base,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? selColor : scheme.outlineVariant,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Text(
            diff.name.toUpperCase(),
            style: TextStyle(
              color: isSelected ? (isDark ? selColor : scheme.onSurface) : scheme.onSurface,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlayerIndicator() {
    final scheme = Theme.of(context).colorScheme;
    final Color ring = currentPlayer == 'X' ? playerColors[0] : playerColors[1];

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + 0.08 * math.sin(_pulseController.value * math.pi * 2);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ring.withOpacity(0.1),
              ring.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ring.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: ring.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 2),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ring.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                currentPlayer == 'X' ? Icons.close_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: ring,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Player $currentPlayer Turn',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ring,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final gameCount = xScore + oScore + draws; //Use actual draws count

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final base = isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Player X Wins:',
                style: TextStyle(color: scheme.onSurface),
              ),
              Text(
                '$xScore',
                style: TextStyle(
                  color: playerColors[0],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Player O Wins:',
                style: TextStyle(color: scheme.onSurface),
              ),
              Text(
                '$oScore',
                style: TextStyle(
                  color: playerColors[1],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Draws:',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              Text(
                '$draws', // Use draws counter directly
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Divider(color: scheme.outlineVariant, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Games:',
                style: TextStyle(color: scheme.onSurface),
              ),
              Text(
                '$gameCount',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSheetContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
          const SizedBox(height: 20),

          // Theme Mode
          Text('Theme',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  'System',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: themeModeNotifier.value == ThemeMode.system 
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: themeModeNotifier.value == ThemeMode.system,
                onSelected: (_) {
                  if (themeModeNotifier.value != ThemeMode.system) {
                    themeModeNotifier.value = ThemeMode.system;
                    Navigator.pop(context);
                  }
                },
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  'Light',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: themeModeNotifier.value == ThemeMode.light 
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: themeModeNotifier.value == ThemeMode.light,
                onSelected: (_) {
                  if (themeModeNotifier.value != ThemeMode.light) {
                    themeModeNotifier.value = ThemeMode.light;
                    Navigator.pop(context);
                  }
                },
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  'Dark',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: themeModeNotifier.value == ThemeMode.dark 
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: themeModeNotifier.value == ThemeMode.dark,
                onSelected: (_) {
                  if (themeModeNotifier.value != ThemeMode.dark) {
                    themeModeNotifier.value = ThemeMode.dark;
                    Navigator.pop(context);
                  }
                },
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Theme Color',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 10),
          ValueListenableBuilder<Color>(
            valueListenable: seedColorNotifier,
            builder: (context, currentColor, _) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _ColorDot(Color(0xFF0BA5A4)),
                        const SizedBox(width: 6),
                        const Text('Teal'),
                      ],
                    ),
                    selected: currentColor.value == 0xFF0BA5A4,
                    onSelected: (selected) {
                      if (selected && currentColor.value != 0xFF0BA5A4) {
                        Navigator.pop(context);
                        seedColorNotifier.value = const Color(0xFF0BA5A4);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _ColorDot(Color(0xFF0B6EFD)),
                        const SizedBox(width: 6),
                        const Text('Blue'),
                      ],
                    ),
                    selected: currentColor.value == 0xFF0B6EFD,
                    onSelected: (selected) {
                      if (selected && currentColor.value != 0xFF0B6EFD) {
                        Navigator.pop(context);
                        seedColorNotifier.value = const Color(0xFF0B6EFD);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _ColorDot(Color(0xFF6750A4)),
                        const SizedBox(width: 6),
                        const Text('Purple'),
                      ],
                    ),
                    selected: currentColor.value == 0xFF6750A4,
                    onSelected: (selected) {
                      if (selected && currentColor.value != 0xFF6750A4) {
                        Navigator.pop(context);
                        seedColorNotifier.value = const Color(0xFF6750A4);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _ColorDot(Color(0xFF2BA24C)),
                        const SizedBox(width: 6),
                        const Text('Green'),
                      ],
                    ),
                    selected: currentColor.value == 0xFF2BA24C,
                    onSelected: (selected) {
                      if (selected && currentColor.value != 0xFF2BA24C) {
                        Navigator.pop(context);
                        seedColorNotifier.value = const Color(0xFF2BA24C);
                      }
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Game Mode Section
          Text('Game Mode',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  icon: Icons.people,
                  label: '2 Players',
                  isSelected: gameMode == GameMode.twoPlayer,
                  onTap: () {
                    if (!mounted) return;
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (!mounted) return;
                      setState(() {
                        gameMode = GameMode.twoPlayer;
                        resetGame();
                      });
                    });
                  },
                  color: playerColors[0],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  icon: Icons.computer,
                  label: 'vs Computer',
                  isSelected: gameMode == GameMode.computer,
                  onTap: () {
                    if (!mounted) return;
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (!mounted) return;
                      setState(() {
                        gameMode = GameMode.computer;
                        resetGame();
                      });
                    });
                  },
                  color: playerColors[1],
                ),
              ),
            ],
          ),

          // Starting Player Section
          const SizedBox(height: 20),
          Text(
            'Starting Player',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  icon: Icons.close,
                  label: 'Start X',
                  isSelected: _startWithX == true,
                  onTap: () {
                    if (!mounted) return;
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (!mounted) return;
                      setState(() {
                        _startWithX = true;
                        resetGame();
                      });
                    });
                  },
                  color: playerColors[0],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModeButton(
                  icon: Icons.radio_button_unchecked,
                  label: 'Start O',
                  isSelected: _startWithX == false,
                  onTap: () {
                    if (!mounted) return;
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (!mounted) return;
                      setState(() {
                        _startWithX = false;
                        resetGame();
                      });
                    });
                  },
                  color: playerColors[1],
                ),
              ),
            ],
          ),

          // Difficulty Section (only show when computer mode is selected)
          if (gameMode == GameMode.computer) ...[
            const SizedBox(height: 20),
            Text(
              'Difficulty',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (var diff in Difficulty.values)
                  _buildDifficultyButton(
                    diff,
                    isSelected: difficulty == diff,
                    onTap: () {
                      if (!mounted) return;
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 120), () {
                        if (!mounted) return;
                        setState(() {
                          difficulty = diff;
                          resetGame();
                        });
                      });
                    },
                  ),
              ],
            ),
          ],

          // Add Sound Settings Section before Stats Section
          const SizedBox(height: 30),
          Text(
            'Sound Settings',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Builder(builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            final isDark = scheme.brightness == Brightness.dark;
            final base = isDark ? scheme.surfaceContainerHigh : scheme.surface;
            return Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sound Effects',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                  ),
                  Switch(
                    value: isSoundEnabled,
                    onChanged: (value) {
                      setState(() {
                        isSoundEnabled = value;
                      });
                    },
                    activeColor: scheme.primary,
                    activeTrackColor: scheme.primary.withValues(alpha: 0.3),
                    inactiveThumbColor: scheme.outline,
                    inactiveTrackColor:
                        scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            );
          }),

          // Stats Section
          const SizedBox(height: 30),
          Text(
            'Statistics',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          _buildStatistics(),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {
              resetStats();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.errorContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Reset Stats'),
          ),
        ],
        ),
      ),
    );
  }


  void _showSettingsSheet() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // Prevent tap from bubbling up
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
                maxWidth: 400,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  child: _buildSettingsSheetContent(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.games_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tic Tac Toe',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_aiThinking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Thinking…',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.settings_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: _showSettingsSheet,
              tooltip: 'Settings',
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: isLoading ? 0.0 : 1.0,
            child: SafeArea(
                child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Score Board
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildScoreCard(
                                'Player X', xScore, playerColors[0]),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildScoreCard(
                                'Player O', oScore, playerColors[1]),
                          ),
                        ],
                      ),
                    ),

                    // Current Player Indicator
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCurrentPlayerIndicator(),
                    ),

                    // Game Board
                    Flexible(
                      flex: 4,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          children: [
                            IgnorePointer(
                              ignoring:
                                  _isHandlingTap || _aiThinking || gameOver,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                      blurRadius: 40,
                                      offset: const Offset(0, 4),
                                      spreadRadius: -8,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: GridView.builder(
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12.0,
                                    crossAxisSpacing: 12.0,
                                  ),
                                  itemCount: 9,
                                  itemBuilder: (context, index) => Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => handleTap(index),
                                      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                      child: _buildGridCell(index),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Disabled overlay when input is blocked
                            Positioned.fill(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: (_isHandlingTap || _aiThinking)
                                    ? 0.08
                                    : 0.0,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceTint
                                          .withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10), // reduced from 15

                    // Result and Button Area
                    SizedBox(
                      height: 100, // Fixed height
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (result.isNotEmpty)
                            SizedBox(
                              height: 50, // Fixed height for result
                              child: AnimatedBuilder(
                                animation: _celebrationController,
                                builder: (context, child) => Transform.scale(
                                  scale: 1 +
                                      (_celebrationController.value * 0.2),
                                  child: AnimatedOpacity(
                                    opacity: result.isNotEmpty ? 1 : 0,
                                    duration:
                                        const Duration(milliseconds: 300),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (Theme.of(context)
                                                    .colorScheme
                                                    .brightness ==
                                                Brightness.dark)
                                            ? Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHigh
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerLowest,
                                        borderRadius:
                                            BorderRadius.circular(25),
                                        border: Border.all(
                                          color: result.contains('X')
                                              ? playerColors[0]
                                              : result.contains('O')
                                                  ? playerColors[1]
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        result,
                                        style: TextStyle(
                                          fontSize: 20, // Reduced font size
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 8),

                          // Dynamic countdown timer (only show when game is over)
                          if (gameOver)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'New game starts in $_countdownSeconds seconds...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading Screen
          if (isLoading)
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Lottie.asset(
                        'assets/animations/new-tic.json',
                        repeat: true,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 +
                              0.1 *
                                  math.sin(_shimmerController.value * math.pi),
                          child: Text(
                            "Tic Tac Toe",
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Confetti
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.05,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String player, int score, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceVariant.withOpacity(0.3),
            scheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 2),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    player.contains('X') ? Icons.close_rounded : Icons.radio_button_unchecked_rounded,
                    size: 12,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    player,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
