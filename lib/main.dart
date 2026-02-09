import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

void main() {
  runApp(const KlixApp());
}

class KlixApp extends StatelessWidget {
  const KlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050510),
        useMaterial3: true,
        fontFamily: 'Roboto', // Default, looks clean
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Entrance animation for initial message
    Future.delayed(const Duration(milliseconds: 500), () {
      _addMessage(
        ChatMessage(
          text: "System Online.\nI am Klix. Ready to assist.",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
    _listKey.currentState?.insertItem(
      _messages.length - 1,
      duration: const Duration(milliseconds: 600),
    );
    _scrollToBottom();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();
    _addMessage(
      ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );

    setState(() {
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      // Determine the backend URL based on platform
      String baseUrl = 'http://localhost:8000';
      if (!kIsWeb && Platform.isAndroid) {
        // Use 10.0.2.2 for emulator, but for physical device we need the computer's local IP.
        // I'll set it here based on the detected IP: 10.221.110.33
        // You can change this if your computer's IP changes.
        baseUrl = 'http://10.221.110.33:8000'; 
      }

      // Connect to local backend
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'user_id': 'flutter_user',
        }),
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _addMessage(
            ChatMessage(
              text: data['response'],
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        } else {
          _addMessage(
            ChatMessage(
              text: "System Error: ${response.statusCode}",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _addMessage(
          ChatMessage(
            text: "Connection Failed: Is the backend running?\nError: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100, // Extra scroll for effect
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
        ),
        title: const GlowingTitle(),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            children: [
              Expanded(
                child: AnimatedList(
                  key: _listKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 20),
                  initialItemCount: _messages.length,
                  itemBuilder: (context, index, animation) {
                    return SlideTransition(
                      position: animation.drive(Tween(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutBack))),
                      child: FadeTransition(
                        opacity: animation,
                        child: _MessageBubble(message: _messages[index]),
                      ),
                    );
                  },
                ),
              ),
              if (_isTyping) const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TypingIndicator(),
                    )
                  ),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32, top: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF151525).withOpacity(0.6),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.add_rounded),
                  color: Colors.cyanAccent,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.cyanAccent,
                    decoration: InputDecoration(
                      hintText: 'Enter command...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.cyan, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                       color: Colors.cyanAccent,
                       blurRadius: 10,
                       offset: Offset(0, 2),
                       spreadRadius: -4
                    )
                  ]
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded),
                  color: Colors.black,
                  onPressed: () => _handleSubmitted(_textController.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlowingTitle extends StatelessWidget {
  const GlowingTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.cyanAccent, Colors.purpleAccent, Colors.white],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: const Text(
        'KLIX',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: Colors.white, // Required for ShaderMask
          shadows: [
            Shadow(blurRadius: 20, color: Colors.blueAccent, offset: Offset(0, 0)),
          ]
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
             const _Avatar(),
             const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          const Color(0xFF2A2A3E).withOpacity(0.9),
                          const Color(0xFF1F1F2E).withOpacity(0.9)
                        ],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser 
                      ? const Color(0xFF6366F1).withOpacity(0.4) 
                      : Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isUser 
                  ? null 
                  : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.bolt, color: Colors.cyanAccent, size: 20),
    );
  }
}

// Complex animated background with floating orbs
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Reduced number of particles for performance
  final List<Orb> _orbs = List.generate(5, (i) => Orb());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BackgroundPainter(
            orbs: _orbs,
            animationValue: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Orb {
  final Color color;
  final Offset offset;
  final double radius;

  Orb() : 
    color = [Colors.purpleAccent, Colors.blueAccent, Colors.deepPurple][math.Random().nextInt(3)].withOpacity(0.2),
    offset = Offset(math.Random().nextDouble(), math.Random().nextDouble()),
    radius = math.Random().nextDouble() * 150 + 50;
}

class BackgroundPainter extends CustomPainter {
  final List<Orb> orbs;
  final double animationValue;

  BackgroundPainter({required this.orbs, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark background base
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0A12),
    );

    for (var i = 0; i < orbs.length; i++) {
      final orb = orbs[i];
      // Move orbs in circular paths
      final dx = math.cos(animationValue * 2 * math.pi + i) * 50;
      final dy = math.sin(animationValue * 2 * math.pi + i) * 50;

      final center = Offset(
        orb.offset.dx * size.width + dx,
        orb.offset.dy * size.height + dy,
      );

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [orb.color, orb.color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: center, radius: orb.radius));

      canvas.drawCircle(center, orb.radius, paint);
    }
    
    // Grid overlay for "tech" feel
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    double gridSize = 40;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) => true;
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double t = _controller.value;
              final double offset = index * 0.2;
              double val = (t - offset) % 1.0;
              if (val < 0) val += 1.0;
              // Sharp pulse
              double opacity = (math.sin(val * math.pi * 2) + 1) / 2;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.5 + (0.5 * opacity)),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.cyanAccent.withOpacity(opacity), blurRadius: 4),
                  ]
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
