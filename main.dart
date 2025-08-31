import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:math_expressions/math_expressions.dart';

void main() {
  runApp(const TinaApp());
}

class TinaApp extends StatelessWidget {
  const TinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tina',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          iconTheme: IconThemeData(color: Colors.purple),
        ),
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _web = false;
  String _backend = 'https://69e7c32aa94e.ngrok-free.app'; // change to LAN IP when testing on device

  bool _ttsEnabled = false;
  late stt.SpeechToText _speech;
  bool _listening = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setPitch(1.0);
    _flutterTts.awaitSpeakCompletion(true);

    _loadHistory(); // 👈 load today's chats only
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final db = await _openChatDb();

    // Only load today's messages
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final rows = await db.query(
      "chats",
      where: "ts >= ?",
      whereArgs: [todayStart],
      orderBy: "ts ASC",
    );

    setState(() {
      _messages.clear();
      _messages.addAll(rows.map((r) =>
          _Msg(
            who: r["who"] == "you" ? Who.you : Who.tina,
            text: r["text"] as String,
          ),
      ));
    });
  }

  Future<void> _listen() async {
    if (!_listening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
        },
        onError: (error) {
          debugPrint('Speech error: $error');
        },
      );
      if (available) {
        setState(() => _listening = true);
        await _speech.listen(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          localeId: 'en_US',
          onResult: (result) {
            setState(() {
              _input.text = result.recognizedWords;
              _input.selection = TextSelection.fromPosition(
                TextPosition(offset: _input.text.length),
              );
            });
          },
        );
      }
    } else {
      setState(() => _listening = false);
      await _speech.stop();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    // 👤 User message
    setState(() {
      _messages.add(_Msg(who: Who.you, text: text));
      _input.clear();
    });
    await _saveMessage(Who.you, text); // save to DB
    _scrollToBottom();

    // 👉 First try offline logic
    final localReply = await _handleLocalLogic(text);
    if (localReply.isNotEmpty) {
      setState(() {
        _messages.add(_Msg(who: Who.tina, text: localReply));
      });
      await _saveMessage(Who.tina, localReply); // save Tina reply
      if (_ttsEnabled) {
        await _flutterTts.speak(localReply);
      }
      _scrollToBottom();
      return;
    }

    // 👉 Otherwise call backend as usual
    try {
      final res = await http.post(
        Uri.parse("$_backend/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": text, "allow_web": _web}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data["reply"] ?? "";
        setState(() {
          _messages.add(_Msg(who: Who.tina, text: reply));
        });
        await _saveMessage(Who.tina, reply); // save Tina reply
        if (_ttsEnabled) {
          await _flutterTts.speak(reply);
        }
      } else {
        final errorText = "Server error ${res.statusCode}";
        setState(() {
          _messages.add(_Msg(who: Who.tina, text: errorText));
        });
        await _saveMessage(Who.tina, errorText);
      }
    } catch (e) {
      final errorText = "Could not reach backend. Is it running?\n$_backend/chat";
      setState(() {
        _messages.add(_Msg(who: Who.tina, text: errorText));
      });
      await _saveMessage(Who.tina, errorText);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Text("🌸", style: TextStyle(fontSize: 22)),
            SizedBox(width: 6),
            Text("Tina"),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _ttsEnabled ? "Disable Voice" : "Enable Voice",
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              setState(() => _ttsEnabled = !_ttsEnabled);
              if (!_ttsEnabled) {
                await _flutterTts.stop();
              }
            },
          ),
          Switch(
            value: _web,
            onChanged: (v) => setState(() => _web = v),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Clear History",
            onPressed: () async {
              final db = await _openChatDb();
              await db.delete("chats");
              setState(() => _messages.clear());
            },
          ),
          IconButton(
            tooltip: "Chat History",
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: "Backend URL",
            icon: const Icon(Icons.link),
            onPressed: () async {
              final controller = TextEditingController(text: _backend);
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text("Set Backend URL"),
                  content: TextField(controller: controller),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text("Save"))
                  ],
                ),
              );
              if (ok == true) setState(() => _backend = controller.text.trim());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final align = m.who == Who.you ? Alignment.centerRight : Alignment.centerLeft;
                final bg = m.who == Who.you ? Colors.purple[100] : Colors.purple[300];
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _listening ? "Stop Listening" : "Start Listening",
                  icon: Icon(
                    _listening ? Icons.mic : Icons.mic_none,
                    color: Colors.purple,
                  ),
                  onPressed: _listen,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  label: const Text("Send"),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum Who { you, tina }

class _Msg {
  final Who who;
  final String text;
  _Msg({required this.who, required this.text});
}

// -----------------------------
// 🔹 Chat History Database
// -----------------------------
Future<Database> _openChatDb() async {
  final databasesPath = await getDatabasesPath();
  final path = join(databasesPath, "chat_history.db");

  return openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE chats (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          who TEXT,
          text TEXT,
          ts INTEGER
        )
      ''');
    },
  );
}

Future<void> _saveMessage(Who who, String text) async {
  final db = await _openChatDb();
  await db.insert("chats", {
    "who": who == Who.you ? "you" : "tina",
    "text": text,
    "ts": DateTime.now().millisecondsSinceEpoch,
  });
}

// -----------------------------
// 🔹 Dictionary + Math logic
// -----------------------------
Future<Database> _openDictionaryDb() async {
  final databasesPath = await getDatabasesPath();
  final path = join(databasesPath, "dictionary.db");

  // Copy from assets if not exists
  if (!await File(path).exists()) {
    final data = await rootBundle.load("assets/dictionary.db");
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  return openDatabase(path);
}

Future<String> _lookupWord(String word) async {
  final db = await _openDictionaryDb();
  final result = await db.query(
    "entries",
    where: "word = ?",
    whereArgs: [word.toLowerCase()],
  );

  if (result.isNotEmpty) {
    return result.first["definition"] as String;
  }
  return "Sorry, I don’t know the meaning of '$word'.";
}

Future<String> _handleLocalLogic(String text) async {
  final lower = text.toLowerCase();

  // Dictionary lookup
  if (lower.startsWith("define ")) {
    final word = lower.replaceFirst("define ", "").trim();
    final def = await _lookupWord(word);
    return "Definition of $word: $def";
  }

  // Letter counting
  if (lower.startsWith("how many") && lower.contains(" in ")) {
    final parts = lower.split(" in ");
    if (parts.length == 2) {
      final letter = parts[0].replaceFirst("how many", "").trim();
      final word = parts[1].trim();
      if (letter.isNotEmpty && word.isNotEmpty) {
        final count = word.split('').where((c) => c == letter).length;
        return 'The letter "$letter" appears $count time(s) in "$word".';
      }
    }
  }

  // 👉 Math solving
  final mathRawPattern = RegExp(r'^[0-9\(\)\+\-\*\/\s\^\.xX×÷]+$');

  if (lower.startsWith("what is") || lower.startsWith("calculate") || mathRawPattern.hasMatch(lower)) {
    try {
      var expr = lower
          .replaceAll("what is", "")
          .replaceAll("calculate", "")
          .trim();

      // normalize operators
      expr = expr.replaceAll('×', '*').replaceAll('x', '*').replaceAll('X', '*');
      expr = expr.replaceAll('÷', '/');

      Parser p = Parser();
      Expression exp = p.parse(expr);
      ContextModel cm = ContextModel();
      double result = exp.evaluate(EvaluationType.REAL, cm);

      // Pretty print (remove .0 if integer)
      final out = result % 1 == 0 ? result.toInt().toString() : result.toString();
      return "The result is $out";
    } catch (e) {
      return "I couldn't solve that math expression.";
    }
  }

  return ""; // nothing matched
}

// -----------------------------
// 🔹 History Screen (all chats grouped by date)
// -----------------------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, List<Map<String, dynamic>>> _groupedChats = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final db = await _openChatDb();
    final rows = await db.query("chats", orderBy: "ts ASC");

    // Group messages by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var row in rows) {
      final ts = DateTime.fromMillisecondsSinceEpoch(row["ts"] as int);
      final dateKey =
          "${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(row);
    }

    setState(() {
      _groupedChats = grouped;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_groupedChats.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Chat History")),
        body: const Center(child: Text("No history yet.")),
      );
    }

    final dates = _groupedChats.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Chat History")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: dates.length,
        itemBuilder: (context, i) {
          final date = dates[i];
          final chats = _groupedChats[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📅 Date header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      date,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              // 📝 Messages of that day
              ...chats.map((m) {
                final who = m["who"] == "you" ? "You" : "Tina";
                final text = m["text"];
                final ts =
                DateTime.fromMillisecondsSinceEpoch(m["ts"] as int);
                final timeStr =
                    "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";

                return ListTile(
                  leading: who == "You"
                      ? const Icon(Icons.person, color: Colors.purple)
                      : const Icon(Icons.smart_toy, color: Colors.blue),
                  title: Text("$who: $text"),
                  subtitle: Text(timeStr),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}
