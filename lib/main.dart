import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() {
  runApp(const WhosWinningApp());
}

enum AppearanceMode { system, light, dark }

// User preferences, saved to SharedPreferences. Screens listen to this so
// changes apply immediately everywhere.
class AppSettings extends ChangeNotifier {
  double scoreFontSize = ScoreSheetMetrics.defaultFontSize;
  AppearanceMode appearance = AppearanceMode.system;

  // null lets the app follow the system setting
  Brightness? get brightness => switch (appearance) {
        AppearanceMode.system => null,
        AppearanceMode.light => Brightness.light,
        AppearanceMode.dark => Brightness.dark,
      };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    scoreFontSize = prefs.getDouble('scoreFontSize') ?? scoreFontSize;
    final appearanceName = prefs.getString('appearance');
    appearance = AppearanceMode.values.firstWhere(
      (mode) => mode.name == appearanceName,
      orElse: () => AppearanceMode.system,
    );
    notifyListeners();
  }

  Future<void> setScoreFontSize(double fontSize) async {
    scoreFontSize = fontSize;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scoreFontSize', fontSize);
  }

  Future<void> setAppearance(AppearanceMode mode) async {
    appearance = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance', mode.name);
  }
}

class WhosWinningApp extends StatefulWidget {
  const WhosWinningApp({super.key});

  @override
  State<WhosWinningApp> createState() => _WhosWinningAppState();
}

class _WhosWinningAppState extends State<WhosWinningApp> {
  final AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => CupertinoApp(
        title: "Who's Winning?",
        theme: CupertinoThemeData(
          primaryColor: CupertinoColors.systemBlue,
          brightness: _settings.brightness,
        ),
        home: GameListScreen(settings: _settings),
      ),
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
  final AppSettings settings;

  const GameListScreen({super.key, required this.settings});

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

  void _showSettings() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SettingsScreen(settings: widget.settings),
      ),
    );
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
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings),
          onPressed: _showSettings,
        ),
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
          settings: widget.settings,
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 28.0;

  // Follows the slider while dragging; saved to settings when the drag ends
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.settings.scoreFontSize.clamp(_minFontSize, _maxFontSize);
  }

  Widget _buildAppearanceOption(String title, AppearanceMode mode) {
    return CupertinoListTile(
      title: Text(title),
      trailing: widget.settings.appearance == mode
          ? const Icon(CupertinoIcons.check_mark)
          : null,
      onTap: () => widget.settings.setAppearance(mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final metrics = ScoreSheetMetrics.of(context, fontSize: _fontSize);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('APPEARANCE'),
              children: [
                _buildAppearanceOption('Use System Setting', AppearanceMode.system),
                _buildAppearanceOption('Light', AppearanceMode.light),
                _buildAppearanceOption('Dark', AppearanceMode.dark),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('SCORE SHEET'),
              footer: const Text('Changes the size of scores and labels in the score table.'),
              children: [
                CupertinoListTile(
                  title: const Text('Font Size'),
                  additionalInfo: Text('${_fontSize.round()} pt'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: CupertinoSlider(
                          value: _fontSize,
                          min: _minFontSize,
                          max: _maxFontSize,
                          divisions: ((_maxFontSize - _minFontSize) / 2).round(),
                          onChanged: (value) {
                            setState(() {
                              _fontSize = value;
                            });
                          },
                          onChangeEnd: widget.settings.setScoreFontSize,
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('PREVIEW'),
              children: [
                _ScoreCellPreview(metrics: metrics),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// A round label beside a score cell holding two scores and a blank line,
// sized exactly as the score table would draw it
class _ScoreCellPreview extends StatelessWidget {
  final ScoreSheetMetrics metrics;

  const _ScoreCellPreview({required this.metrics});

  @override
  Widget build(BuildContext context) {
    const scores = [12, 5];
    final columnWidth = math.max(
      metrics.minColumnWidth,
      metrics.textWidth('17', metrics.totalStyle) + metrics.scoreCellPadding.horizontal + 4.0 * metrics.scale,
    );
    final rowHeight = (scores.length + 1) * metrics.scoreLineHeight + metrics.scoreCellPadding.vertical;

    return Container(
      color: metrics.paperColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: metrics.labelColumnWidth,
                height: rowHeight,
                child: Center(child: Text('Round 1', style: metrics.labelStyle)),
              ),
              Container(
                width: columnWidth,
                height: rowHeight,
                padding: metrics.scoreCellPadding,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: metrics.inkColor, width: 2.0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final score in scores)
                      SizedBox(
                        height: metrics.scoreLineHeight,
                        child: Text('$score', style: metrics.scoreStyle, textAlign: TextAlign.end),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            width: metrics.labelColumnWidth + columnWidth,
            height: metrics.totalRowHeight,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: metrics.inkColor, width: 1.0)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: metrics.labelColumnWidth,
                  child: Center(child: Text('Total', style: metrics.labelStyle)),
                ),
                Container(
                  width: columnWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4) * metrics.scale,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: metrics.inkColor, width: 2.0)),
                  ),
                  child: Text('17', style: metrics.totalStyle, textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GameDetailScreen extends StatefulWidget {
  final Game game;
  final VoidCallback onGameUpdated;
  final AppSettings settings;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.onGameUpdated,
    required this.settings,
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

  // Number pad entry with a +/- button, since the iOS number pad has no minus key
  Widget _buildScoreField(TextEditingController controller, ValueChanged<String> onSubmitted) {
    return CupertinoTextField(
      controller: controller,
      placeholder: 'Score',
      keyboardType: TextInputType.number,
      autofocus: true,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      prefix: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        child: const Text('+/−'),
        onPressed: () {
          final text = controller.text;
          final flipped = text.startsWith('-') ? text.substring(1) : '-$text';
          controller.value = TextEditingValue(
            text: flipped,
            selection: TextSelection.collapsed(offset: flipped.length),
          );
        },
      ),
      onSubmitted: onSubmitted,
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
          child: _buildScoreField(scoreController, (value) {
            final score = int.tryParse(value) ?? 0;
            _addScoreEntry(round, player, score);
            Navigator.of(context).pop();
          }),
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
          child: _buildScoreField(scoreController, (value) {
            final score = int.tryParse(value) ?? 0;
            _updateScoreEntry(round, player, scoreIndex, score);
            Navigator.of(context).pop();
          }),
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

  double _getLargestNumberInColumn(Player player, ScoreSheetMetrics metrics) {
    double maxWidth = 0.0;

    // Check all rounds for this player's scores
    for (final round in game.rounds) {
      final playerScores = round.scores[player.id] ?? [];
      for (final score in playerScores) {
        maxWidth = math.max(maxWidth, metrics.textWidth('${score.score}', metrics.scoreStyle));
      }

      // Also check the running total
      final total = _calculateRoundSubtotal(round, player);
      maxWidth = math.max(maxWidth, metrics.textWidth('$total', metrics.totalStyle));
    }

    return maxWidth;
  }

  double _getColumnWidth(Player player, ScoreSheetMetrics metrics) {
    final maxWidth = _getLargestNumberInColumn(player, metrics);

    // Fit the team name on one line where possible; longer names wrap
    final nameWidth = math.min(
      metrics.maxNameWidth,
      metrics.textWidth(player.name, metrics.totalStyle) + 16.0 * metrics.scale,
    );

    // Add extra space for the cell's horizontal padding
    final scoresWidth = maxWidth + metrics.scoreCellPadding.horizontal + 4.0 * metrics.scale;
    return math.max(metrics.minColumnWidth, math.max(nameWidth, scoresWidth));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final metrics = ScoreSheetMetrics.of(context, fontSize: widget.settings.scoreFontSize);
    double columnWidth(Player player) => _getColumnWidth(player, metrics);

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
                            color: metrics.paperColor,
                            child: LayoutBuilder(
                              builder: (context, viewport) => SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                // Fill the space between the bars so horizontal swipes
                                // work below the table too, not just on it
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: CustomPaint(
                                        painter: TableGridPainter(
                                          players: game.players,
                                          rounds: game.rounds,
                                          getColumnWidth: columnWidth,
                                          isEditMode: isEditMode,
                                          metrics: metrics,
                                        ),
                                        child: Column(
                                          children: [
                                            // Header row with team names
                                            Container(
                                              height: metrics.headerHeight(isEditMode),
                                              child: Row(
                                                children: [
                                                  // Empty corner cell
                                                  Container(
                                                    width: metrics.labelColumnWidth,
                                                    child: Center(
                                                      child: Text(
                                                        '',
                                                        style: metrics.totalStyle,
                                                      ),
                                                    ),
                                                  ),
                                                  // Team name columns
                                                  ...game.players.map((player) {
                                                    return Container(
                                                      width: columnWidth(player),
                                                      child: Center(
                                                        child: isEditMode
                                                            ? Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  Text(
                                                                    player.name.length > 20 
                                                                        ? '${player.name.substring(0, 20)}...' 
                                                                        : player.name,
                                                                    style: metrics.totalStyle,
                                                                    textAlign: TextAlign.center,
                                                                    maxLines: 2,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                  const SizedBox(height: 1),
                                                                  CupertinoButton(
                                                                    padding: EdgeInsets.zero,
                                                                    child: Icon(
                                                                      CupertinoIcons.delete,
                                                                      size: metrics.iconSize,
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
                                                                style: metrics.totalStyle,
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
                                                final rowHeight = metrics.totalRowHeight;
                                          
                                                return Container(
                                                  height: rowHeight,
                                                  child: Row(
                                                    children: [
                                                      // Subtotal label
                                                      Container(
                                                        width: metrics.labelColumnWidth,
                                                        child: Center(
                                                          child: Text(
                                                            'Total',
                                                            style: metrics.labelStyle,
                                                          ),
                                                        ),
                                                      ),
                                                      // Subtotal values
                                                      ...game.players.map((player) {
                                                        return Container(
                                                          width: columnWidth(player),
                                                                                                            child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4) * metrics.scale,
                                                          child: Text(
                                                            '${_calculateRoundSubtotal(round, player)}',
                                                            style: metrics.totalStyle,
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
                                                final rowHeight = metrics.scoreRowHeight(round, game.players, isEditMode);
                                          
                                                return Container(
                                                  height: rowHeight,
                                                  child: Row(
                                                    children: [
                                                      // Round label
                                                      Container(
                                                        width: metrics.labelColumnWidth,
                                                        child: Center(
                                                          child: isEditMode
                                                              ? Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    Text(
                                                                      'Round ${round.roundNumber}',
                                                                      style: metrics.labelStyle,
                                                                    ),
                                                                    const SizedBox(height: 1),
                                                                    CupertinoButton(
                                                                      padding: EdgeInsets.zero,
                                                                      child: Icon(
                                                                        CupertinoIcons.delete,
                                                                        size: metrics.iconSize,
                                                                        color: CupertinoColors.destructiveRed,
                                                                      ),
                                                                      onPressed: () => _deleteRound(round),
                                                                    ),
                                                                  ],
                                                                )
                                                              : Text(
                                                                  'Round ${round.roundNumber}',
                                                                  style: metrics.labelStyle,
                                                                ),
                                                        ),
                                                      ),
                                                      // Score cells
                                                      ...game.players.map((player) {
                                                        final playerScores = round.scores[player.id] ?? [];
                                                        // Tapping anywhere in the cell adds a score; tapping an existing score edits it
                                                        return GestureDetector(
                                                          behavior: HitTestBehavior.opaque,
                                                          onTap: () => _addScore(round, player),
                                                          child: Container(
                                                            width: columnWidth(player),
                                                            padding: metrics.scoreCellPadding,
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.end,
                                                              mainAxisAlignment: MainAxisAlignment.start,
                                                              children: [
                                                                ...playerScores.asMap().entries.map((scoreEntry) {
                                                                  final scoreIndex = scoreEntry.key;
                                                                  final score = scoreEntry.value;
                                                                  return GestureDetector(
                                                                    onTap: () => _editScore(round, player, scoreIndex),
                                                                    child: SizedBox(
                                                                      height: metrics.scoreLineHeight,
                                                                      child: Text(
                                                                        '${score.score}',
                                                                        style: metrics.scoreStyle,
                                                                        textAlign: TextAlign.end,
                                                                      ),
                                                                    ),
                                                                  );
                                                                }),
                                                              ],
                                                            ),
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
                            ),
                          ),
                  ),
                  
                  // Sticky Add Round button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: metrics.paperColor,
                      border: Border(
                        top: BorderSide(
                          color: metrics.inkColor,
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

// Score table colors for light and dark mode
const CupertinoDynamicColor scoreSheetInk = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF2C2C2C),
  darkColor: Color(0xFFE5E5EA),
);
const CupertinoDynamicColor scoreSheetPaper = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFEFEFE),
  darkColor: Color(0xFF1C1C1E),
);

// Sizes and colors for the score table, with sizes derived from the score font
// size and the device's text size setting. The table and its grid lines both
// read from here so they always agree. Sizes match the original fixed layout at
// 16pt with no system text scaling.
class ScoreSheetMetrics {
  static const double defaultFontSize = 16.0;

  // Delete buttons keep the platform's minimum tap target regardless of text size
  static const double _deleteButtonHeight = 44.0;

  final double fontSize;
  final TextScaler textScaler;
  // Text and grid lines
  final Color inkColor;
  // Table background
  final Color paperColor;

  const ScoreSheetMetrics({
    this.fontSize = defaultFontSize,
    this.textScaler = TextScaler.noScaling,
    this.inkColor = const Color(0xFF2C2C2C),
    this.paperColor = const Color(0xFFFEFEFE),
  });

  // Metrics for the current text size setting and light or dark mode
  factory ScoreSheetMetrics.of(BuildContext context, {required double fontSize}) {
    return ScoreSheetMetrics(
      fontSize: fontSize,
      textScaler: MediaQuery.textScalerOf(context),
      inkColor: scoreSheetInk.resolveFrom(context),
      paperColor: scoreSheetPaper.resolveFrom(context),
    );
  }

  // How much larger everything is than the original 16pt layout
  double get scale => textScaler.scale(fontSize) / defaultFontSize;

  double get scoreLineHeight => 22.0 * scale;
  EdgeInsets get scoreCellPadding => const EdgeInsets.fromLTRB(8, 6, 8, 2) * scale;
  double get labelColumnWidth => 100.0 * scale;
  double get totalRowHeight => 40.0 * scale;
  double get minColumnWidth => 64.0 * scale;
  double get maxNameWidth => 110.0 * scale;
  double get iconSize => 16.0 * scale;

  // Room for a two-line team name, plus a delete button in edit mode
  double headerHeight(bool isEditMode) =>
      60.0 * scale + (isEditMode ? _deleteButtonHeight - 14.0 : 0.0);

  // Unscaled sizes: Text widgets apply the device's text scaling themselves
  TextStyle get scoreStyle => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: inkColor,
      );
  TextStyle get totalStyle => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: inkColor,
      );
  TextStyle get labelStyle => TextStyle(
        fontSize: fontSize * 14.0 / defaultFontSize,
        fontWeight: FontWeight.bold,
        color: inkColor,
      );

  // Height of a round's scores row: one line per score in the fullest cell (at
  // least one), plus a blank line beneath for the next score.
  double scoreRowHeight(Round round, List<Player> players, bool isEditMode) {
    final maxScores = players.fold<int>(0, (max, player) {
      final playerScores = round.scores[player.id] ?? [];
      return playerScores.length > max ? playerScores.length : max;
    });
    final contentHeight = (math.max(maxScores, 1) + 1) * scoreLineHeight + scoreCellPadding.vertical;
    // Edit mode needs room for the round label and its delete button
    return isEditMode
        ? math.max(_deleteButtonHeight + 36.0 * scale, contentHeight)
        : contentHeight;
  }

  // Width of a single line of text as it will be drawn
  double textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    painter.layout();
    return painter.width;
  }
}

class TableGridPainter extends CustomPainter {
  final List<Player> players;
  final List<Round> rounds;
  final double Function(Player) getColumnWidth;
  final bool isEditMode;
  final ScoreSheetMetrics metrics;

  TableGridPainter({
    required this.players,
    required this.rounds,
    required this.getColumnWidth,
    required this.isEditMode,
    required this.metrics,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = metrics.inkColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final boldPaint = Paint()
      ..color = metrics.inkColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Calculate column positions
    double currentX = metrics.labelColumnWidth; // First column holds the round labels
    
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
    double currentY = metrics.headerHeight(isEditMode);
    
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
        
        // Subtotal row only ever holds one value
        currentY += metrics.totalRowHeight;
        
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
        currentY += metrics.scoreRowHeight(round, players, isEditMode);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
