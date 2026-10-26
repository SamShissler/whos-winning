import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() {
  runApp(const ScoresheetApp());
}

class ScoresheetApp extends StatelessWidget {
  const ScoresheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Scoresheet',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: const GameListScreen(),
    );
  }
}

class Game {
  final String id;
  String name;
  final DateTime createdAt;
  DateTime lastModified;
  final List<Player> players;
  final List<Round> rounds;

  Game({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastModified,
    required this.players,
    required this.rounds,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'players': players.map((p) => p.toJson()).toList(),
      'rounds': rounds.map((r) => r.toJson()).toList(),
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      lastModified: DateTime.parse(json['lastModified']),
      players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
      rounds: (json['rounds'] as List).map((r) => Round.fromJson(r)).toList(),
    );
  }
}

class Player {
  final String id;
  final String name;
  int totalScore;

  Player({
    required this.id,
    required this.name,
    this.totalScore = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'totalScore': totalScore,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      totalScore: json['totalScore'] ?? 0,
    );
  }
}

class Round {
  final String id;
  int roundNumber;
  final Map<String, List<ScoreEntry>> scores;
  final DateTime timestamp;

  Round({
    required this.id,
    required this.roundNumber,
    required this.scores,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roundNumber': roundNumber,
      'scores': scores.map((key, value) => MapEntry(key, value.map((s) => s.toJson()).toList())),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Round.fromJson(Map<String, dynamic> json) {
    return Round(
      id: json['id'],
      roundNumber: json['roundNumber'],
      scores: (json['scores'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key, 
          (value as List).map((s) => ScoreEntry.fromJson(s)).toList()
        ),
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ScoreEntry {
  final String id;
  final int score;
  final String label;
  final DateTime timestamp;

  ScoreEntry({
    required this.id,
    required this.score,
    required this.label,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'score': score,
      'label': label,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      id: json['id'],
      score: json['score'],
      label: json['label'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class GameListScreen extends StatefulWidget {
  const GameListScreen({super.key});

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  List<Game> games = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Game> get _filteredGames {
    if (_searchQuery.isEmpty) {
      return games;
    }
    return games.where((game) =>
        game.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Future<void> _loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getStringList('games') ?? [];
    setState(() {
      games = gamesJson
          .map((json) => Game.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveGames() async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = games
        .map((game) => jsonEncode(game.toJson()))
        .toList();
    await prefs.setStringList('games', gamesJson);
  }

  void _createNewGame() {
    final nameController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Game'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'Game name',
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _addNewGame(value);
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Create'),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _addNewGame(nameController.text);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _addNewGame(String name) {
    final newGame = Game(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      players: [],
      rounds: [],
    );

    setState(() {
      games.add(newGame);
    });
    _saveGames();
  }

  void _deleteGame(Game game) {
    setState(() {
      games.remove(game);
    });
    _saveGames();
  }

  Future<bool> _confirmDeleteGame() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete Game'),
        content: const Text('Are you sure you want to delete this game? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _editGameNameFromList(Game game) {
    final nameController = TextEditingController(text: game.name);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Game Name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'Game name',
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _updateGameNameInList(game, value);
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Save'),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _updateGameNameInList(game, nameController.text);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _updateGameNameInList(Game game, String newName) {
    setState(() {
      game.name = newName;
      game.lastModified = DateTime.now();
    });
    _saveGames();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Games'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: _createNewGame,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search games...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            Expanded(
              child: _filteredGames.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.doc_text,
                            size: 48,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'No games yet' : 'No games found',
                            style: const TextStyle(
                              fontSize: 18,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Create your first game to get started!',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredGames.length,
                      itemBuilder: (context, index) {
                        final game = _filteredGames[index];
                        return Dismissible(
                          key: ValueKey(game.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: CupertinoColors.destructiveRed,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              CupertinoIcons.delete,
                              color: CupertinoColors.white,
                            ),
                          ),
                          confirmDismiss: (_) => _confirmDeleteGame(),
                          onDismissed: (_) => _deleteGame(game),
                          child: GestureDetector(
                            onLongPress: () => _editGameNameFromList(game),
                            child: CupertinoListTile(
                              title: Text(game.name),
                              subtitle: Text(_formatDate(game.lastModified)),
                              trailing: CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Icon(CupertinoIcons.chevron_right),
                                onPressed: () => _showGameDetail(game),
                              ),
                              onTap: () => _showGameDetail(game),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameDetail(Game game) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => GameDetailScreen(
          game: game,
          onGameUpdated: _loadGames,
        ),
      ),
    );
  }
}

class GameDetailScreen extends StatefulWidget {
  final Game game;
  final VoidCallback onGameUpdated;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.onGameUpdated,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late Game game;
  bool isEditMode = false;
  final TextEditingController _teamNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    game = widget.game;
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _saveGame() async {
    game.lastModified = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getStringList('games') ?? [];
    
    // Find and update the current game
    final gameIndex = gamesJson.indexWhere((json) {
      final gameData = jsonDecode(json);
      return gameData['id'] == game.id;
    });
    
    if (gameIndex != -1) {
      gamesJson[gameIndex] = jsonEncode(game.toJson());
    }
    
    await prefs.setStringList('games', gamesJson);
    widget.onGameUpdated();
  }

  void _editGameName() {
    final nameController = TextEditingController(text: game.name);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Game Name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'Game name',
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _updateGameName(value);
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Save'),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _updateGameName(nameController.text);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _updateGameName(String newName) {
    setState(() {
      game.name = newName;
    });
    _saveGame();
  }

  void _showAddTeamDialog() {
    _teamNameController.clear();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Team'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: _teamNameController,
            placeholder: 'Team name',
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _addTeam(value);
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Add'),
            onPressed: () {
              if (_teamNameController.text.isNotEmpty) {
                _addTeam(_teamNameController.text);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _addTeam(String name) {
    setState(() {
      game.players.add(Player(
        id: const Uuid().v4(),
        name: name,
      ));
    });
    _saveGame();
  }

  void _deleteTeam(Player player) {
    setState(() {
      game.players.remove(player);
      // Remove all scores for this player from all rounds
      for (final round in game.rounds) {
        round.scores.remove(player.id);
      }
    });
    _saveGame();
  }

  void _addNewRound() {
    final newRound = Round(
      id: const Uuid().v4(),
      roundNumber: game.rounds.length + 1,
      scores: Map.fromEntries(
        game.players.map((player) => MapEntry(player.id, <ScoreEntry>[])),
      ),
      timestamp: DateTime.now(),
    );

    setState(() {
      game.rounds.add(newRound);
    });
    _saveGame();
  }

  void _deleteRound(Round round) {
    setState(() {
      game.rounds.remove(round);
      // Renumber remaining rounds
      for (int i = 0; i < game.rounds.length; i++) {
        game.rounds[i].roundNumber = i + 1;
      }
    });
    _saveGame();
  }

  void _deleteGame() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete Game'),
        content: const Text('Are you sure you want to delete this game? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final prefs = await SharedPreferences.getInstance();
              final gamesJson = prefs.getStringList('games') ?? [];
              
              // Remove the current game
              gamesJson.removeWhere((json) {
                final gameData = jsonDecode(json);
                return gameData['id'] == game.id;
              });
              
              await prefs.setStringList('games', gamesJson);
              widget.onGameUpdated();
              
              // Navigate back to the game list
              if (!mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _addScore(Round round, Player player) {
    final scoreController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Add Score - ${player.name}'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: scoreController,
            placeholder: 'Score',
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (value) {
              final score = int.tryParse(value) ?? 0;
              _addScoreEntry(round, player, score);
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Add'),
            onPressed: () {
              final score = int.tryParse(scoreController.text) ?? 0;
              _addScoreEntry(round, player, score);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _addScoreEntry(Round round, Player player, int score) {
    setState(() {
      final playerScores = round.scores[player.id] ?? [];
      playerScores.add(ScoreEntry(
        id: const Uuid().v4(),
        score: score,
        label: '',
        timestamp: DateTime.now(),
      ));
      round.scores[player.id] = playerScores;
      _updatePlayerTotal(player);
    });
    _saveGame();
  }

  void _editScore(Round round, Player player, int scoreIndex) {
    final playerScores = round.scores[player.id] ?? [];
    if (scoreIndex >= playerScores.length) return;

    final scoreEntry = playerScores[scoreIndex];
    final scoreController = TextEditingController(text: scoreEntry.score.toString());

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Edit Score - ${player.name}'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: scoreController,
            placeholder: 'Score',
            keyboardType: TextInputType.number,
            autofocus: true,
            onSubmitted: (value) {
              final score = int.tryParse(value) ?? 0;
              _updateScoreEntry(round, player, scoreIndex, score);
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Delete'),
            isDestructiveAction: true,
            onPressed: () {
              _deleteScoreEntry(round, player, scoreIndex);
              Navigator.of(context).pop();
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Save'),
            onPressed: () {
              final score = int.tryParse(scoreController.text) ?? 0;
              _updateScoreEntry(round, player, scoreIndex, score);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _updateScoreEntry(Round round, Player player, int scoreIndex, int newScore) {
    setState(() {
      final playerScores = round.scores[player.id] ?? [];
      if (scoreIndex < playerScores.length) {
        playerScores[scoreIndex] = ScoreEntry(
          id: playerScores[scoreIndex].id,
          score: newScore,
          label: playerScores[scoreIndex].label,
          timestamp: DateTime.now(),
        );
        round.scores[player.id] = playerScores;
        _updatePlayerTotal(player);
      }
    });
    _saveGame();
  }

  void _deleteScoreEntry(Round round, Player player, int scoreIndex) {
    setState(() {
      final playerScores = round.scores[player.id] ?? [];
      if (scoreIndex < playerScores.length) {
        playerScores.removeAt(scoreIndex);
        round.scores[player.id] = playerScores;
        _updatePlayerTotal(player);
      }
    });
    _saveGame();
  }

  void _updatePlayerTotal(Player player) {
    int total = 0;
    for (final round in game.rounds) {
      final playerScores = round.scores[player.id];
      if (playerScores != null && playerScores.isNotEmpty) {
        total += playerScores.fold(0, (sum, entry) => sum + entry.score);
      }
    }
    player.totalScore = total;
  }

  int _calculateRoundSubtotal(Round round, Player player) {
    int runningTotal = 0;
    
    // Add all previous rounds
    for (int i = 0; i < game.rounds.indexOf(round); i++) {
      final previousRound = game.rounds[i];
      final previousScores = previousRound.scores[player.id];
      if (previousScores != null && previousScores.isNotEmpty) {
        runningTotal += previousScores.fold(0, (sum, entry) => sum + entry.score);
      }
    }
    
    // Add current round scores
    final currentScores = round.scores[player.id];
    if (currentScores != null && currentScores.isNotEmpty) {
      runningTotal += currentScores.fold(0, (sum, entry) => sum + entry.score);
    }
    
    return runningTotal;
  }

  double _getLargestNumberInColumn(Player player) {
    double maxWidth = 0.0;
    
    // Check all rounds for this player's scores
    for (final round in game.rounds) {
      final playerScores = round.scores[player.id] ?? [];
      for (final score in playerScores) {
        final scoreText = '${score.score}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: scoreText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        maxWidth = math.max(maxWidth, textPainter.width);
      }
      
      // Also check the running total
      final total = _calculateRoundSubtotal(round, player);
      final totalText = '$total';
      final totalPainter = TextPainter(
        text: TextSpan(
          text: totalText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      totalPainter.layout();
      maxWidth = math.max(maxWidth, totalPainter.width);
    }
    
    return maxWidth;
  }

  double _getColumnWidth(Player player) {
    final maxWidth = _getLargestNumberInColumn(player);
    // Add extra space for the "+" button (20px icon + 8px spacing + 16px padding)
    return math.max(110.0, maxWidth + 44.0);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: GestureDetector(
          onTap: _editGameName,
          child: Text(game.name),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text(isEditMode ? 'Done' : 'Edit'),
              onPressed: () {
                setState(() {
                  isEditMode = !isEditMode;
                });
              },
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.person_add),
              onPressed: _showAddTeamDialog,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: game.players.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.person_2,
                      size: 48,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No teams yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add teams to start scoring!',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      child: const Text('Add Team'),
                      onPressed: _showAddTeamDialog,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Scrollable scoresheet content
                  Expanded(
                    child: game.rounds.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.chart_bar,
                                  size: 48,
                                  color: const Color(0xFF8B8B8B),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No rounds yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF8B8B8B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add a round to start scoring!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8B8B8B),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                CupertinoButton.filled(
                                  child: const Text('Add Round'),
                                  onPressed: _addNewRound,
                                ),
                              ],
                            ),
                          )
                        : Container(
                            color: const Color(0xFFFEFEFE),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child:                                 CustomPaint(
                                  painter: TableGridPainter(
                                    players: game.players,
                                    rounds: game.rounds,
                                    getColumnWidth: _getColumnWidth,
                                    isEditMode: isEditMode,
                                  ),
                                  child: Column(
                                    children: [
                                      // Header row with team names
                                      Container(
                                        height: isEditMode ? 90 : 60,
                                        child: Row(
                                          children: [
                                            // Empty corner cell
                                            Container(
                                              width: 100,
                                              child: const Center(
                                                child: Text(
                                                  '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF2C2C2C),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Team name columns
                                            ...game.players.map((player) {
                                              return Container(
                                                width: _getColumnWidth(player),
                                                child: Center(
                                                  child: isEditMode
                                                      ? Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(
                                                              player.name.length > 20 
                                                                  ? '${player.name.substring(0, 20)}...' 
                                                                  : player.name,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 16,
                                                                color: Color(0xFF2C2C2C),
                                                              ),
                                                              textAlign: TextAlign.center,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            const SizedBox(height: 1),
                                                            CupertinoButton(
                                                              padding: EdgeInsets.zero,
                                                              child: const Icon(
                                                                CupertinoIcons.delete,
                                                                size: 16,
                                                                color: CupertinoColors.destructiveRed,
                                                              ),
                                                              onPressed: () => _deleteTeam(player),
                                                            ),
                                                          ],
                                                        )
                                                      : Text(
                                                          player.name.length > 20 
                                                                  ? '${player.name.substring(0, 20)}...' 
                                                                  : player.name,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                            color: Color(0xFF2C2C2C),
                                                          ),
                                                          textAlign: TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                      ),
                                      
                                      // Rounds content
                                      ...List.generate(game.rounds.length * 2, (index) {
                                        final roundIndex = index ~/ 2;
                                        final isSubtotal = index % 2 == 1;
                                        final round = game.rounds[roundIndex];
                                      
                                        if (isSubtotal) {
                                          // Subtotal row - fixed height since it only contains one value
                                          final rowHeight = 40.0;
                                          
                                          return Container(
                                            height: rowHeight,
                                            child: Row(
                                              children: [
                                                // Subtotal label
                                                Container(
                                                  width: 100,
                                                  child: const Center(
                                                    child: Text(
                                                      'Total',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Color(0xFF2C2C2C),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Subtotal values
                                                ...game.players.map((player) {
                                                  return Container(
                                                    width: _getColumnWidth(player),
                                                                                                      child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    child: Text(
                                                      '${_calculateRoundSubtotal(round, player)}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Color(0xFF2C2C2C),
                                                      ),
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          );
                                        } else {
                                          // Scores row
                                          final maxScores = game.players.fold<int>(0, (max, player) {
                                            final playerScores = round.scores[player.id] ?? [];
                                            return playerScores.length > max ? playerScores.length : max;
                                          });
                                          
                                          final rowHeight = math.max(isEditMode ? 80.0 : 60.0, maxScores * 22.0);
                                          
                                          return Container(
                                            height: rowHeight,
                                            child: Row(
                                              children: [
                                                // Round label
                                                Container(
                                                  width: 100,
                                                  child: Center(
                                                    child: isEditMode
                                                        ? Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Text(
                                                                'Round ${round.roundNumber}',
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 14,
                                                                  color: Color(0xFF2C2C2C),
                                                                ),
                                                              ),
                                                              const SizedBox(height: 1),
                                                              CupertinoButton(
                                                                padding: EdgeInsets.zero,
                                                                child: const Icon(
                                                                  CupertinoIcons.delete,
                                                                  size: 16,
                                                                  color: CupertinoColors.destructiveRed,
                                                                ),
                                                                onPressed: () => _deleteRound(round),
                                                              ),
                                                            ],
                                                          )
                                                        : Text(
                                                            'Round ${round.roundNumber}',
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                              color: Color(0xFF2C2C2C),
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                                // Score cells
                                                ...game.players.map((player) {
                                                  final playerScores = round.scores[player.id] ?? [];
                                                  return Container(
                                                    width: _getColumnWidth(player),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        // Add score button on the left
                                                        GestureDetector(
                                                          onTap: () => _addScore(round, player),
                                                          child: const Icon(
                                                            CupertinoIcons.plus_circle,
                                                            size: 20,
                                                            color: Color(0xFF8B8B8B),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        // Scores on the right
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.end,
                                                            mainAxisAlignment: MainAxisAlignment.start,
                                                            children: [
                                                              // Show individual scores with edit functionality
                                                              if (playerScores.isNotEmpty)
                                                                ...playerScores.asMap().entries.map((scoreEntry) {
                                                                  final scoreIndex = scoreEntry.key;
                                                                  final score = scoreEntry.value;
                                                                  return GestureDetector(
                                                                    onTap: () => _editScore(round, player, scoreIndex),
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(vertical: 0.5),
                                                                      child: Text(
                                                                        '${score.score}',
                                                                        style: const TextStyle(
                                                                          fontSize: 16,
                                                                          fontWeight: FontWeight.w500,
                                                                          color: Color(0xFF2C2C2C),
                                                                        ),
                                                                        textAlign: TextAlign.end,
                                                                      ),
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          );
                                        }
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  
                  // Sticky Add Round button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEFEFE),
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFF2C2C2C),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: isEditMode
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CupertinoButton.filled(
                                child: const Text('Add Round'),
                                onPressed: _addNewRound,
                              ),
                              CupertinoButton(
                                child: const Text('Delete Game'),
                                onPressed: _deleteGame,
                              ),
                            ],
                          )
                        : Center(
                            child: CupertinoButton.filled(
                              child: const Text('Add Round'),
                              onPressed: _addNewRound,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TableGridPainter extends CustomPainter {
  final List<Player> players;
  final List<Round> rounds;
  final double Function(Player) getColumnWidth;
  final bool isEditMode;

  TableGridPainter({
    required this.players,
    required this.rounds,
    required this.getColumnWidth,
    required this.isEditMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2C2C2C)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final boldPaint = Paint()
      ..color = const Color(0xFF2C2C2C)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Calculate column positions
    double currentX = 100.0; // First column (round labels) is 100px wide
    
    // Draw vertical lines (excluding the rightmost line)
    for (int i = 0; i < players.length; i++) {
      final lineX = currentX;
      
      // Draw continuous vertical line from top to bottom
      canvas.drawLine(
        Offset(lineX, 0),
        Offset(lineX, size.height),
        i == 0 ? boldPaint : paint, // First line (after round labels) is bold
      );
      
      currentX += getColumnWidth(players[i]);
    }

    // Draw horizontal lines
    final headerHeight = isEditMode ? 90.0 : 60.0;
    double currentY = headerHeight; // Header height
    
    // Header bottom border (bold)
    canvas.drawLine(
      Offset(0, currentY),
      Offset(size.width, currentY),
      boldPaint,
    );

    // Draw horizontal lines for each round and subtotal (excluding the bottom line)
    for (int i = 0; i < rounds.length * 2; i++) {
      final roundIndex = i ~/ 2;
      final isSubtotal = i % 2 == 1;
      final round = rounds[roundIndex];
      
      if (isSubtotal) {
        // Top border of subtotal row
        canvas.drawLine(
          Offset(0, currentY),
          Offset(size.width, currentY),
          paint,
        );
        
        // Fixed height for subtotal row since it only contains one value
        final rowHeight = 40.0;
        currentY += rowHeight;
        
        // Only draw bottom border if this isn't the last subtotal row
        if (i < rounds.length * 2 - 1) {
          canvas.drawLine(
            Offset(0, currentY),
            Offset(size.width, currentY),
            paint,
          );
        }
      } else {
        // Scores row
        final maxScores = players.fold<int>(0, (max, player) {
          final playerScores = round.scores[player.id] ?? [];
          return playerScores.length > max ? playerScores.length : max;
        });
        
        final rowHeight = math.max(isEditMode ? 80.0 : 60.0, maxScores * 22.0);
        currentY += rowHeight;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
