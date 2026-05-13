import 'package:flutter/material.dart';
import '../../api/habit_api_service.dart';
import '../../models/ai_habit_dto.dart';
import '../../models/habit.dart';
import '../paywall/paywall_screen.dart';

class AiGeneratorScreen extends StatefulWidget {
  const AiGeneratorScreen({super.key});

  @override
  State<AiGeneratorScreen> createState() => _AiGeneratorScreenState();
}

class _AiGeneratorScreenState extends State<AiGeneratorScreen>
    with TickerProviderStateMixin {
  final _api = HabitApiService.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  String? _error;
  List<AiHabitDto> _generatedHabits = [];
  final Set<int> _selectedIndices = {};

  bool _isAddingHabits = false;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Usage stats
  int _remaining = 0;
  int _totalLimit = 0;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final stats = await _api.getGlobalStats();
      debugPrint('AI Usage Stats: $stats');
      
      setState(() {
        _isPro = stats['isPro'] as bool? ?? false;
        
        // Handle both camelCase and PascalCase from server
        _remaining = (stats['aiGenerationsRemaining'] ?? stats['AiGenerationsRemaining']) as int? ?? 0;
        _totalLimit = (stats['aiTotalLimit'] ?? stats['AiTotalLimit']) as int? ?? (_isPro ? 5 : 2);
      });
    } catch (e) {
      debugPrint('Error loading AI stats: $e');
      // On error, we don't want to show 5/5 if we don't know
      setState(() {
        _remaining = 0;
        _totalLimit = _isPro ? 5 : 2;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  static const List<List<Color>> _gradients = [
    [Color(0xFFDA22FF), Color(0xFF9733EE)],
    [Color(0xFF00B4DB), Color(0xFF0083B0)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFF512F), Color(0xFFDD2476)],
    [Color(0xFF4776E6), Color(0xFF8E54E9)],
    [Color(0xFFFFB75E), Color(0xFFED8F03)],
  ];

  LinearGradient _gradientFor(int index) {
    final colors = _gradients[index % _gradients.length];
    return LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    // 🛑 Client-side limit check: If no generations left and not PRO, go to paywall
    if (!_isPro && _remaining <= 0) {
      final purchased = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PaywallScreen()),
      );
      if (purchased == true) {
        _loadState();
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _generatedHabits = [];
      _selectedIndices.clear();
    });

    try {
      final result = await _api.generateAiRoutine(prompt);
      
      setState(() {
        _generatedHabits = result['habits'] as List<AiHabitDto>;
        _isPro = result['isPro'] as bool? ?? false;

        // Use unified keys
        _remaining = (result['aiGenerationsRemaining'] ?? result['AiGenerationsRemaining'] ?? result['remaining']) as int? ?? 0;
        _totalLimit = (result['aiTotalLimit'] ?? result['AiTotalLimit'] ?? result['totalLimit']) as int? ?? (_isPro ? 5 : 2);
        
        _selectedIndices.addAll(List.generate(_generatedHabits.length, (i) => i));
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      String errMsg = e.toString().replaceFirst('Exception: ', '');
      if (errMsg.contains('ProRequired')) {
        final purchased = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
        if (purchased == true) {
          _loadState(); 
        }
      } else {
        setState(() => _error = errMsg);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSelectedHabits() async {
    if (_selectedIndices.isEmpty) return;

    setState(() => _isAddingHabits = true);
    int addedCount = 0;

    try {
      for (final index in _selectedIndices) {
        final h = _generatedHabits[index];
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
          repeatType: HabitRepeatType.values[rTypeIdx],
          repeatDaysOfWeek: days,
          repeatTimesPerPeriod: times,
          repeatPeriod: rTypeIdx == 3 ? 1 : null,
        );
        addedCount++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF00E676)),
              const SizedBox(width: 8),
              Text('$addedCount habit${addedCount != 1 ? 's' : ''} added to your dashboard!'),
            ]),
            backgroundColor: const Color(0xFF1A2E1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('ProRequired')) {
          _showLimitSheet(msg.replaceFirst('ProRequired: ', ''));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _isAddingHabits = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPromptCard(),
                  if (_isLoading) _buildLoadingState(),
                  if (_error != null) _buildError(),
                  if (_generatedHabits.isNotEmpty) ...[
                    _buildResultsSection(),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          if (_generatedHabits.isNotEmpty && !_isLoading)
            _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String subtext;
    Color subtextColor;

    if (_isPro) {
      subtext = _remaining > 0 
        ? '$_remaining generations left today • PRO' 
        : 'Daily limit reached • PRO';
      subtextColor = _remaining > 0 ? const Color(0xFFDA22FF) : Colors.red.shade400;
    } else {
      subtext = _remaining > 0 
        ? '$_remaining free generations left' 
        : '0 free generations left';
      subtextColor = _remaining > 0 ? const Color(0xFF8A8F9E) : Colors.red.shade400;
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                            ).createShader(bounds),
                            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text('AI Routine Builder',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtext, style: TextStyle(color: subtextColor, fontSize: 12)),
                    ],
                  ),
                ),
                if (_isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard() {
    double progress = _totalLimit > 0 ? _remaining / _totalLimit : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDA22FF).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDA22FF).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("What's your goal?",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. "I want to lose weight, sleep better and reduce stress"',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF0C1017),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDA22FF), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isPro ? 'Daily limit' : 'Total limit',
                style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12),
              ),
              Text(
                '$_remaining of $_totalLimit left',
                style: TextStyle(
                  color: _remaining > 0 ? const Color(0xFFDA22FF) : Colors.red.shade400,
                  fontSize: 12, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDA22FF)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _isLoading ? null : _generate,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: _isLoading
                    ? null
                    : const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)]),
                  color: _isLoading ? const Color(0xFF2A2F3A) : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isLoading ? [] : [
                    BoxShadow(
                      color: const Color(0xFFDA22FF).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _isLoading ? 'AI is building your routine...' : 'Generate My Routine ⚡',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Quick ideas:', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip('🏃 Lose weight'),
              _buildChip('🧠 Learn programming'),
              _buildChip('😴 Sleep better'),
              _buildChip('📚 Read more'),
              _buildChip('💰 Save money'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return GestureDetector(
      onTap: () {
        _controller.text = label.replaceAll(RegExp(r'^[^\s]+\s'), '');
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1017),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDA22FF).withOpacity(0.2)),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDA22FF).withOpacity(0.5 * _pulseAnimation.value),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('AI is crafting your routine...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Analyzing your goals and building the perfect habits',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    String displayError = _error!;
    if (displayError.contains('subtype') || displayError.contains('index')) {
      displayError = "Connection sync issue. Please redeploy the backend or try again later. ⚡";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1215),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            "System Glitch",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            displayError,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _error = null),
            child: Text("DISMISS", style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Your AI Routine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_selectedIndices.length}/${_generatedHabits.length} selected',
              style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Tap to select habits you want to add',
          style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
        const SizedBox(height: 16),
        ...List.generate(_generatedHabits.length, (i) => _buildHabitCard(i)),
      ],
    );
  }

  Widget _buildHabitCard(int index) {
    final habit = _generatedHabits[index];
    final isSelected = _selectedIndices.contains(index);
    final gradient = _gradientFor(index);
    final icon = _iconFor(habit.icon);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIndices.remove(index);
          } else {
            _selectedIndices.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF161A22) : const Color(0xFF0F1218),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
              ? const Color(0xFFDA22FF).withOpacity(0.3)
              : Colors.white.withOpacity(0.04),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFDA22FF).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: isSelected ? gradient : null,
                color: isSelected ? null : const Color(0xFF1C1F26),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                color: isSelected ? Colors.white : const Color(0xFF4A4E5A),
                size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF8A8F9E),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                  if (habit.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(habit.description,
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                  ? const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)])
                  : null,
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    final count = _selectedIndices.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1017),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: GestureDetector(
        onTap: _isAddingHabits || count == 0 ? null : _addSelectedHabits,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: count > 0
              ? const LinearGradient(colors: [Color(0xFFFF7A55), Color(0xFFFF4848)])
              : null,
            color: count == 0 ? const Color(0xFF2A2F3A) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: count > 0 ? [
              BoxShadow(
                color: const Color(0xFFFF524A).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isAddingHabits)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              else
                const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                _isAddingHabits
                  ? 'Adding habits...'
                  : count == 0
                    ? 'Select at least one habit'
                    : 'Add $count Habit${count != 1 ? 's' : ''} to Dashboard',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLimitSheet(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Color(0xFF161A22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFDA22FF).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDA22FF).withOpacity(0.2)),
              ),
              child: const Icon(Icons.star_rounded, color: Color(0xFFDA22FF), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Limit Reached',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDA22FF).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Upgrade to Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Maybe later',
                style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
