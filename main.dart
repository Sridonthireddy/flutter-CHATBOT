import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TinaApp());
}

class TinaApp extends StatelessWidget {
  const TinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tina 🌸',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
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
  String _backend = "http://127.0.0.1:5000"; // change to LAN IP when testing on device

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Msg(who: Who.you, text: text));
      _input.clear();
    });
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse("$_backend/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": text, "allow_web": _web}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _messages.add(_Msg(who: Who.tina, text: data["reply"] ?? ""));
        });
      } else {
        setState(() {
          _messages.add(_Msg(who: Who.tina, text: "Server error ${res.statusCode}"));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_Msg(who: Who.tina, text: "Could not reach backend. Is it running?\n$_backend/chat"));
      });
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
        title: const Text("Tina 🌸"),
        actions: [
          Switch(
            value: _web,
            onChanged: (v) => setState(() => _web = v),
          ),
          const SizedBox(width: 8),
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
                const SizedBox(width: 8),
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
