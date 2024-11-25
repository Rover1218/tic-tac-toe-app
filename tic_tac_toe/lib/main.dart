import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const TicTacToeApp());

enum GameMode { twoPlayer, computer }

enum Difficulty { easy, medium, hard }

class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TicTacToe(),
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
  int draws = 0; // Add this line
  late AnimationController _pulseController;
  late AnimationController _celebrationController;
  late AnimationController _shimmerController;
  late ConfettiController _confettiController;
  bool isLoading = true;
  static const List<Color> playerColors = [
    Color(0xFFE94560), // Soft Red for X
    Color(0xFF2ECC71), // Emerald Green for O
  ];
  GameMode gameMode = GameMode.twoPlayer;
  Difficulty difficulty = Difficulty.medium;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isSoundEnabled = true; // Add this line

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

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Add initial loading animation
    Future.delayed(const Duration(seconds: 2), () {
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
    _audioPlayer.dispose();
    _controller.dispose();
    _pulseController.dispose();
    _celebrationController.dispose();
    _shimmerController.dispose();
    _confettiController.dispose();
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

  void resetGame() {
    setState(() {
      board = List.filled(9, '');
      currentPlayer = 'X';
      result = '';
      gameOver = false;
    });
  }

  void resetStats() {
    setState(() {
      xScore = 0;
      oScore = 0;
      draws = 0; // Add this line
    });
  }

  void handleTap(int index) {
    if (board[index] == '' && !gameOver) {
      // Play move sound immediately before state update
      _playSound('move');

      setState(() {
        board[index] = currentPlayer;
        _controller.forward(from: 0.0);

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
        } else if (!board.contains('')) {
          result = 'It\'s a Draw!';
          gameOver = true;
          draws++;
          Future.delayed(const Duration(milliseconds: 50), () {
            _playSound('draw');
          });
        } else {
          currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
          if (gameMode == GameMode.computer && currentPlayer == 'O') {
            makeComputerMove();
          }
        }
      });
    }
  }

  void makeComputerMove() {
    if (gameOver || currentPlayer == 'X') return;

    int move;
    switch (difficulty) {
      case Difficulty.easy:
        move = getRandomMove();
        break;
      case Difficulty.medium:
        move =
            math.Random().nextDouble() < 0.7 ? getBestMove() : getRandomMove();
        break;
      case Difficulty.hard:
        move = getBestMove();
        break;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      handleTap(move);
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
        board[i] = 'O';
        int score = minimax(board, 0, false, -1000, 1000);
        board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }
    return bestMove;
  }

  int minimax(
      List<String> board, int depth, bool isMaximizing, int alpha, int beta) {
    String result = checkGameResult();
    if (result != '') {
      return result == 'O'
          ? 10 - depth
          : result == 'X'
              ? depth - 10
              : 0;
    }

    if (isMaximizing) {
      int maxEval = -1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == '') {
          board[i] = 'O';
          int eval = minimax(board, depth + 1, false, alpha, beta);
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
          board[i] = 'X';
          int eval = minimax(board, depth + 1, true, alpha, beta);
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
        return true;
      }
    }
    return false;
  }

  Widget _buildGridCell(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: board[index].isNotEmpty
              ? (board[index] == 'X' ? playerColors[0] : playerColors[1])
              : Colors.white24,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: board[index].isNotEmpty
                ? (board[index] == 'X'
                    ? playerColors[0].withOpacity(0.4)
                    : playerColors[1].withOpacity(0.4))
                : Colors.white.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 1,
          ),
          if (board[index].isNotEmpty)
            BoxShadow(
              color: board[index] == 'X'
                  ? playerColors[0].withOpacity(0.2)
                  : playerColors[1].withOpacity(0.2),
              blurRadius: 35,
              spreadRadius: 5,
            ),
        ],
        gradient: board[index].isNotEmpty
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  board[index] == 'X'
                      ? playerColors[0].withOpacity(0.15)
                      : playerColors[1].withOpacity(0.15),
                  Colors.transparent,
                ],
              )
            : null,
      ),
      child: FittedBox(
        // Add FittedBox here
        fit: BoxFit.contain,
        child: Container(
          padding: const EdgeInsets.all(15),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: board[index].isEmpty ? 0 : 60, // Reduced from 70
                fontWeight: FontWeight.bold,
                color: board[index] == 'X' ? playerColors[0] : playerColors[1],
                shadows: [
                  BoxShadow(
                    color: board[index] == 'X'
                        ? playerColors[0].withOpacity(0.8)
                        : playerColors[1].withOpacity(0.8),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: board[index] == 'X'
                        ? playerColors[0].withOpacity(0.4)
                        : playerColors[1].withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: board[index].isEmpty ? 0 : math.pi * 2,
                    child: Transform.scale(
                      scale: board[index].isEmpty
                          ? 1
                          : 1.0 +
                              (0.1 *
                                  math.sin(
                                      _shimmerController.value * math.pi * 2)),
                      child: Text(board[index]),
                    ),
                  );
                },
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors[diff]!.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? colors[diff]! : Colors.white24,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors[diff]!.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Text(
          diff.name.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final gameCount = xScore + oScore + draws; //Use actual draws count

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Player X Wins:',
                style: TextStyle(color: playerColors[0]),
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
                style: TextStyle(color: playerColors[1]),
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
              const Text(
                'Draws:',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '$draws', // Use draws counter directly
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Games:',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                '$gameCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF6A11CB),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Game Mode Section
            const Text(
              'Game Mode',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    icon: Icons.people,
                    label: '2 Players',
                    isSelected: gameMode == GameMode.twoPlayer,
                    onTap: () => setState(() {
                      gameMode = GameMode.twoPlayer;
                      resetGame();
                      Navigator.pop(context);
                    }),
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
                      setState(() {
                        gameMode = GameMode.computer;
                        resetGame();
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
              const Text(
                'Difficulty',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (var diff in Difficulty.values)
                    _buildDifficultyButton(
                      diff,
                      isSelected: difficulty == diff,
                      onTap: () => setState(() {
                        difficulty = diff;
                        resetGame();
                        Navigator.pop(context);
                      }),
                    ),
                ],
              ),
            ],

            // Add Sound Settings Section before Stats Section
            const SizedBox(height: 30),
            const Text(
              'Sound Settings',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sound Effects',
                    style: TextStyle(color: Colors.white),
                  ),
                  Switch(
                    value: isSoundEnabled,
                    onChanged: (value) {
                      setState(() {
                        isSoundEnabled = value;
                      });
                    },
                    activeColor: const Color(0xFF2575FC),
                    activeTrackColor: const Color(0xFF2575FC).withOpacity(0.3),
                    inactiveThumbColor: Colors.white70,
                    inactiveTrackColor: Colors.white24,
                  ),
                ],
              ),
            ),

            // Stats Section
            const SizedBox(height: 30),
            const Text(
              'Statistics',
              style: TextStyle(color: Colors.white70, fontSize: 16),
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
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Stats'),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method for the current player indicator
  Widget _buildCurrentPlayerIndicator() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500), // Add const here
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: Container(
        key: ValueKey<String>(currentPlayer),
        width: 80, // Fixed width
        height: 80, // Fixed height
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: currentPlayer == 'X'
                ? const [Colors.redAccent, Colors.pinkAccent] // Add const here
                : const [
                    Colors.lightBlueAccent,
                    Colors.blueAccent
                  ], // Add const here
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // ignore: prefer_const_constructors_in_immutables, prefer_const_literals_to_create_immutables
          boxShadow: [
            BoxShadow(
              color: currentPlayer == 'X'
                  ? Colors.pinkAccent.withOpacity(0.6)
                  : Colors.blueAccent.withOpacity(0.6),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          // Add Center widget
          child: Text(
            currentPlayer,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black45,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Add this line
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6A11CB).withOpacity(0.8),
                const Color(0xFF2575FC).withOpacity(0.8),
              ],
            ),
          ),
          child: AppBar(
            title: const Text(
              'Tic Tac Toe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
        ),
      ),
      endDrawer: _buildSettingsDrawer(),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A11CB), // Vibrant Purple
                  Color(0xFF2575FC), // Electric Blue
                  Color(0xFF6A11CB), // Vibrant Purple
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: isLoading ? 0.0 : 1.0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Score Board
                      Flexible(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildScoreCard(
                                    'Player X', xScore, playerColors[0]),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildScoreCard(
                                    'Player O', oScore, playerColors[1]),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Current Player Indicator
                      SizedBox(
                        height: 100,
                        child: _buildCurrentPlayerIndicator(),
                      ),

                      const SizedBox(height: 15), // reduced from 20

                      // Game Board
                      Flexible(
                        flex: 4,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 15.0,
                                crossAxisSpacing: 15.0,
                              ),
                              itemCount: 9,
                              itemBuilder: (context, index) => GestureDetector(
                                onTap: () => handleTap(index),
                                child: _buildGridCell(index),
                              ),
                            ),
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
                                          color: (result.contains('X')
                                                  ? playerColors[0]
                                                  : result.contains('O')
                                                      ? playerColors[1]
                                                      : Colors.white)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(25),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (result.contains('X')
                                                      ? playerColors[0]
                                                      : result.contains('O')
                                                          ? playerColors[1]
                                                          : Colors.white)
                                                  .withOpacity(0.3),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          result,
                                          style: const TextStyle(
                                            fontSize: 20, // Reduced font size
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 8),

                            // Reset Button
                            SizedBox(
                              height: 40,
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: ElevatedButton(
                                onPressed: resetGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'New Game',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
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
          ),

          // Loading Screen
          if (isLoading)
            Container(
              color: const Color(0xFF6A11CB),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 +
                              0.1 *
                                  math.sin(_shimmerController.value * math.pi),
                          child: const Text(
                            "Tic Tac Toe",
                            style: TextStyle(
                              color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6), // reduced from 15,8
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // add this
        children: [
          Text(
            player,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16, // reduced from 18
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24, // reduced from 28
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: color,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
