import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';

void main() => runApp(const TicTacToeApp());

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
  late AnimationController _pulseController;
  late AnimationController _celebrationController;
  late AnimationController _shimmerController;
  late ConfettiController _confettiController;
  bool isLoading = true;
  final List<Color> playerColors = [
    const Color(0xFFE94560).withOpacity(0.9), // Soft Red for X
    const Color(0xFF2ECC71).withOpacity(0.9), // Emerald Green for O
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _celebrationController.dispose();
    _shimmerController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void resetGame() {
    setState(() {
      board = List.filled(9, '');
      currentPlayer = 'X';
      result = '';
      gameOver = false;
    });
  }

  void handleTap(int index) {
    if (board[index] == '' && !gameOver) {
      setState(() {
        board[index] = currentPlayer;
        _controller.forward(from: 0.0);
        if (checkWinner(currentPlayer)) {
          _celebrationController.forward(from: 0.0);
          _confettiController.play();
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
        } else {
          currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
        }
      });
    }
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
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: board[index].isEmpty ? 0 : 70,
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
                              math.sin(_shimmerController.value * math.pi * 2)),
                  child: Text(board[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        height: 40,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Transform.scale(
                            scale: currentPlayer == 'X'
                                ? 1 + (_pulseController.value * 0.1)
                                : 1 - (_pulseController.value * 0.1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8), // reduced vertical padding
                              decoration: BoxDecoration(
                                color: currentPlayer == 'X'
                                    ? Colors.pink.withOpacity(0.3)
                                    : Colors.amber.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Current Player: $currentPlayer',
                                style: const TextStyle(
                                  fontSize: 20, // reduced from 24
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
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
