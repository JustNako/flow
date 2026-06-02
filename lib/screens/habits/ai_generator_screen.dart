import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../api/habit_api_service.dart';
import '../../models/ai_habit_dto.dart';
import '../../models/habit.dart';
import '../paywall/paywall_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<AiHabitDto>? habits;
  final bool isLoading;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.habits,
    this.isLoading = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'habits': habits?.map((h) => h.toJson()).toList(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      habits: (json['habits'] as List<dynamic>?)
          ?.map((e) => AiHabitDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AiGeneratorScreen extends StatefulWidget {
  const AiGeneratorScreen({super.key});

  @override
  State<AiGeneratorScreen> createState() => _AiGeneratorScreenState();
}

class _AiGeneratorScreenState extends State<AiGeneratorScreen> with TickerProviderStateMixin {
  final _api = HabitApiService.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  final Set<AiHabitDto> _selectedHabits = {};

  bool _isAddingHabits = false;
  int _remaining = 0;
  int _totalLimit = 0;
  bool _isPro = false;

  late AnimationController _sparkController;

  @override
  void initState() {
    super.initState();
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('ai_chat_history');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        setState(() {
          _messages.clear();
          _messages.addAll(decoded.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)));
        });
        _scrollToBottom();
      } catch (e) {
        debugPrint('Error loading chat history: $e');
        _initDefaultGreeting();
      }
    } else {
      _initDefaultGreeting();
    }
  }

  void _initDefaultGreeting() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: "Hello. What would you like to build today?",
          isUser: false,
        ),
      );
    });
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(_messages.where((m) => !m.isLoading).map((m) => m.toJson()).toList());
    await prefs.setString('ai_chat_history', historyJson);
  }

  Future<void> _loadState() async {
    try {
      final stats = await _api.getGlobalStats();
      setState(() {
        _isPro = stats['isPro'] as bool? ?? false;
        _remaining = (stats['aiGenerationsRemaining'] ?? stats['AiGenerationsRemaining']) as int? ?? 0;
        _totalLimit = (stats['aiTotalLimit'] ?? stats['AiTotalLimit']) as int? ?? (_isPro ? 5 : 2);
      });
    } catch (e) {
      debugPrint('Error loading AI stats: $e');
      setState(() {
        _remaining = 0;
        _totalLimit = _isPro ? 5 : 2;
      });
    }
  }

  @override
  void dispose() {
    _sparkController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    if (!_isPro && _remaining <= 0) {
      final purchased = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (purchased == true) {
        _loadState();
      }
      return;
    }

    _controller.clear();
    _focusNode.unfocus();

    setState(() {
      _messages.add(ChatMessage(text: prompt, isUser: true));
      _messages.add(ChatMessage(text: "", isUser: false, isLoading: true));
    });
    
    _scrollToBottom();

    try {
      final result = await _api.generateAiRoutine(prompt);
      
      setState(() {
        _isPro = result['isPro'] as bool? ?? false;
        _remaining = (result['aiGenerationsRemaining'] ?? result['AiGenerationsRemaining'] ?? result['remaining']) as int? ?? 0;
        _totalLimit = (result['aiTotalLimit'] ?? result['AiTotalLimit'] ?? result['totalLimit']) as int? ?? (_isPro ? 5 : 2);
        
        final habits = result['habits'] as List<AiHabitDto>;
        _messages.removeLast(); // remove loading
        _messages.add(
          ChatMessage(
            text: "Here are some suggestions to help you get started.",
            isUser: false,
            habits: habits,
          ),
        );
      });
      _scrollToBottom();
      _saveChatHistory();
    } catch (e) {
      String errMsg = e.toString().replaceFirst('Exception: ', '');
      if (errMsg.contains('ProRequired')) {
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(text: "You've reached your free limit. Please upgrade to Pro to continue.", isUser: false));
        });
        final purchased = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
        if (purchased == true) {
          _loadState(); 
        }
      } else {
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(text: "Sorry, I encountered an error: $errMsg", isUser: false));
        });
      }
      _scrollToBottom();
      _saveChatHistory();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _addSelectedHabits() async {
    if (_selectedHabits.isEmpty) return;

    if (_selectedHabits.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You can only add up to 10 habits at a time.'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        )
      );
      return;
    }

    setState(() => _isAddingHabits = true);
    int addedCount = 0;

    try {
      for (final h in _selectedHabits) {
        int rTypeIdx = h.repeatType;
        List<int>? days = h.repeatDaysOfWeek;
        int? times = h.repeatTimesPerPeriod;

        if (rTypeIdx == 1 && (days == null || days.isEmpty)) {
          rTypeIdx = 0; 
        } else if (rTypeIdx == 3 && (times == null || times <= 0)) {
          rTypeIdx = 0; 
        }

        if (rTypeIdx < 0 || rTypeIdx >= HabitRepeatType.values.length) {
          rTypeIdx = 0;
        }

        await _api.createHabit(
          title: h.title,
          description: h.description,
          targetDays: h.targetDays,
          unit: h.unit,
          repeatType: HabitRepeatType.values[rTypeIdx],
          repeatDaysOfWeek: days,
          repeatTimesPerPeriod: times,
          repeatPeriod: rTypeIdx == 3 ? 1 : null,
          timeOfDay: h.timeOfDay,
        );
        addedCount++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF8BA888)),
              const SizedBox(width: 8),
              Text('$addedCount habit${addedCount != 1 ? 's' : ''} added!'),
            ]),
            backgroundColor: const Color(0xFF2C2C2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _selectedHabits.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isAddingHabits = false);
    }
  }

  IconData _iconFor(String iconName) {
    switch (iconName) {
      case 'fitness_center': return Icons.fitness_center;
      case 'water_drop': return Icons.water_drop_outlined;
      case 'book': return Icons.book_outlined;
      case 'self_improvement': return Icons.self_improvement;
      case 'code': return Icons.code;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'monitor_heart': return Icons.monitor_heart_outlined;
      case 'spa': return Icons.spa_outlined;
      case 'directions_run': return Icons.directions_run;
      case 'bolt': return Icons.bolt;
      case 'directions_walk': return Icons.directions_walk;
      case 'bedtime': return Icons.bedtime_outlined;
      case 'restaurant': return Icons.restaurant_outlined;
      case 'psychology': return Icons.psychology_outlined;
      case 'savings': return Icons.savings_outlined;
      default: return Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Soft dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFE0E0E0), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Flow AI',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFE0E0E0),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$_remaining/$_totalLimit left${_isPro ? ' • PRO' : ''}',
                style: const TextStyle(color: Color(0xFF8BA888), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // Chat list
          ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(top: 10, bottom: 120 + bottomPadding, left: 16, right: 16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return msg.isUser ? _buildUserMessage(msg) : _buildAiMessage(msg);
            },
          ),
          
          // Floating Input Field
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.only(bottom: bottomPadding + 16, left: 16, right: 16, top: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1A1A).withOpacity(0.0),
                    const Color(0xFF1A1A1A).withOpacity(0.9),
                    const Color(0xFF1A1A1A),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedHabits.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GestureDetector(
                        onTap: _isAddingHabits ? null : _addSelectedHabits,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8BA888), // Sage green
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8BA888).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _isAddingHabits
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)),
                                )
                              : Text(
                                  'Add ${_selectedHabits.length} Habit${_selectedHabits.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'What would you like to build today?',
                              hintStyle: TextStyle(color: Color(0xFF757575), fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            onSubmitted: (_) => _generate(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: _generate,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF8BA888),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF1A1A1A), size: 20),
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
        ],
      ),
    );
  }

  Widget _buildUserMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 15, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAiAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        _buildDot(0),
                        const SizedBox(width: 4),
                        _buildDot(1),
                        const SizedBox(width: 4),
                        _buildDot(2),
                      ],
                    ),
                  )
                else
                  Text(
                    msg.text,
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFFDCDCDC),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                if (msg.habits != null && msg.habits!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildBentoGrid(msg.habits!),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAvatar() {
    return AnimatedBuilder(
      animation: _sparkController,
      builder: (context, child) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD68C7A).withOpacity(0.8 + 0.2 * _sparkController.value), // Terracotta
                const Color(0xFF9F92C6).withOpacity(0.4 + 0.2 * _sparkController.value), // Lavender
                const Color(0xFF1A1A1A).withOpacity(0.0),
              ],
              stops: const [0.2, 0.7, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD68C7A).withOpacity(0.3 * _sparkController.value),
                blurRadius: 10 * _sparkController.value,
                spreadRadius: 2 * _sparkController.value,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _sparkController,
      builder: (context, child) {
        final delay = index * 0.3;
        final value = (_sparkController.value - delay).clamp(0.0, 1.0);
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF8BA888).withOpacity(0.3 + 0.7 * value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildBentoGrid(List<AiHabitDto> habits) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: habits.map((habit) {
        final isSelected = _selectedHabits.contains(habit);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedHabits.remove(habit);
              } else {
                if (_selectedHabits.length >= 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You can only select up to 10 habits.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    )
                  );
                  return;
                }
                _selectedHabits.add(habit);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: habits.length == 1 ? double.infinity : (MediaQuery.of(context).size.width - 48 - 44) / 2, // ~half width minus paddings
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF8BA888).withOpacity(0.15) : const Color(0xFF252525),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF8BA888) : const Color(0xFF333333),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(_iconFor(habit.icon), color: isSelected ? const Color(0xFF8BA888) : const Color(0xFF9F92C6), size: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.of(context).pushNamed(
                              '/add_habit',
                              arguments: habit,
                            );
                            if (result == true && mounted) {
                              setState(() {
                                _selectedHabits.remove(habit); // Uncheck if added individually
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Habit saved and added!'),
                                  backgroundColor: Color(0xFF2C2C2E),
                                  behavior: SnackBarBehavior.floating,
                                )
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.edit_outlined, color: Color(0xFF888888), size: 18),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Color(0xFF8BA888), size: 20)
                        else
                          const Icon(Icons.circle_outlined, color: Color(0xFF555555), size: 20),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  habit.title,
                  style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (habit.unit != null && habit.unit!.isNotEmpty && habit.unit!.toLowerCase() != 'null')
                      '${habit.targetDays} ${habit.unit}'
                    else
                      '${habit.targetDays} time${habit.targetDays > 1 ? 's' : ''}',
                    if (habit.timeOfDay != null && habit.timeOfDay!.isNotEmpty && habit.timeOfDay!.toLowerCase() != 'null' && habit.timeOfDay!.toLowerCase() != 'any time')
                      habit.timeOfDay!
                  ].join(' • '),
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
