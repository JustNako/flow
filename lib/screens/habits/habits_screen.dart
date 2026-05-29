import 'package:flutter/material.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/offline_manager.dart';
import '../../theme/app_theme.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _api = HabitApiService.instance;
  final _authService = AuthService.instance;
  final _offlineManager = OfflineManager.instance;

  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;

  // Для отслеживания какие привычки помечены сегодня
  final Set<String> _togglingIds = {};

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  // ─── Загрузка ──────────────────────────────────────────────────────────────

  Future<void> _loadHabits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final habits = await _api.getHabits();
      setState(() => _habits = habits);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Toggle ────────────────────────────────────────────────────────────────

  Future<void> _toggleHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) return;

    setState(() => _togglingIds.add(id));
    try {
      await _api.toggleHabit(id);
      // No need for full reload, we can just update the local state or wait for sync
      setState(() {
        final index = _habits.indexWhere((h) => h.id == id);
        if (index != -1) {
          final h = _habits[index];
          final wasCompleted = h.isCompletedToday;
          _habits[index] = h.copyWith(
            isCompletedToday: !wasCompleted,
            completedDays: wasCompleted ? h.completedDays - 1 : h.completedDays + 1,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingIds.remove(id));
    }
  }

  // ─── Удаление ──────────────────────────────────────────────────────────────

  Future<void> _deleteHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text('"${habit.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteHabit(id);
      setState(() => _habits.removeWhere((h) => h.id == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ─── Создание ──────────────────────────────────────────────────────────────

  Future<void> _navigateToAddHabit() async {
    final result = await Navigator.of(context).pushNamed('/add_habit');
    if (result == true) {
      _loadHabits();
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildConnectionBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddHabit,
        backgroundColor: context.colors.primary ?? const Color(0xFF7C3AED),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Habit', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      title: Text(
        'All Habits',
        style: TextStyle(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: context.colors.textSecondary),
          onPressed: _loadHabits,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: Icon(Icons.logout, color: context.colors.textSecondary),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
      ],
      elevation: 0,
    );
  }

  // Баннер онлайн / офлайн / синхронизация
  Widget _buildConnectionBanner() {
    return StreamBuilder<ConnectionStatus>(
      stream: _offlineManager.connectionStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || status == ConnectionStatus.connected) {
          return const SizedBox.shrink();
        }

        final (color, icon, text) = switch (status) {
          ConnectionStatus.disconnected => (
            const Color(0xFF7F1D1D),
            Icons.wifi_off,
            'Offline mode — changes will sync when connected',
          ),
          ConnectionStatus.syncing => (
            const Color(0xFF1E3A5F),
            Icons.sync,
            'Syncing...',
          ),
          _ => (const Color(0xFF14532D), Icons.wifi, 'Online'),
        };

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              if (status == ConnectionStatus.syncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.primary ?? const Color(0xFF7C3AED)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: context.colors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: context.colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadHabits,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary ?? const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_habits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.track_changes, color: context.colors.primary ?? const Color(0xFF7C3AED), size: 64),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your journey by adding\nyour first habit below',
              style: TextStyle(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHabits,
      color: context.colors.primary,
      backgroundColor: context.colors.card,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _habits.length,
        itemBuilder: (ctx, i) => _HabitCard(
          habit: _habits[i],
          isToggling: _togglingIds.contains(_habits[i].id),
          onToggle: () => _toggleHabit(_habits[i]),
          onDelete: () => _deleteHabit(_habits[i]),
        ),
      ),
    );
  }
}

// ─── Карточка привычки ────────────────────────────────────────────────────────

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isToggling;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.habit,
    required this.isToggling,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = habit.progress;
    final isComplete = progress >= 1.0;

    return Dismissible(
      key: Key(habit.id ?? habit.title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => false, // подтверждение через onDelete
      onDismissed: (_) {},
      child: GestureDetector(
        onLongPress: onDelete,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isComplete ? context.colors.success.withOpacity(0.1) : context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isComplete
                  ? context.colors.success.withOpacity(0.4)
                  : context.colors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            style: TextStyle(
                              color: isComplete
                                  ? context.colors.success
                                  : context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (habit.description != null && habit.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              habit.description!,
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            habit.repeatLabel,
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Кнопка отметить выполненным
                    GestureDetector(
                      onTap: isToggling ? null : onToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToggling
                              ? context.colors.textSecondary.withOpacity(0.1)
                              : isComplete
                                  ? context.colors.success.withOpacity(0.2)
                                  : (context.colors.primary?.withOpacity(0.15) ?? const Color(0xFF7C3AED).withOpacity(0.15)),
                          border: Border.all(
                            color: isToggling
                                ? context.colors.border
                                : isComplete
                                    ? context.colors.success
                                    : (context.colors.primary ?? const Color(0xFF7C3AED)),
                            width: 2,
                          ),
                        ),
                        child: isToggling
                            ? Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              )
                            : Icon(
                                isComplete
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isComplete
                                    ? context.colors.success
                                    : context.colors.primary,
                                size: 26,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Прогресс-бар
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: context.colors.textSecondary.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete ? context.colors.success : (context.colors.primary ?? const Color(0xFF7C3AED)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${habit.completedDays}/${habit.targetDays}',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom sheet: добавить привычку ─────────────────────────────────────────

class _AddHabitSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _AddHabitSheet({required this.onCreated});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _targetCtrl = TextEditingController(text: '30');
  HabitRepeatType _repeatType = HabitRepeatType.everyDay;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await HabitApiService.instance.createHabit(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        targetDays: int.tryParse(_targetCtrl.text) ?? 30,
        repeatType: _repeatType,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Новая привычка',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Название
            _field(
              controller: _titleCtrl,
              label: 'Название *',
              hint: 'Например: Утренняя зарядка',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите название'
                  : null,
            ),
            const SizedBox(height: 12),
            // Описание
            _field(
              controller: _descCtrl,
              label: 'Описание',
              hint: 'Необязательно',
            ),
            const SizedBox(height: 12),
            // Повторение
            DropdownButtonFormField<HabitRepeatType>(
              value: _repeatType,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Повторение',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              items: HabitRepeatType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getRepeatTypeLabel(type)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _repeatType = val);
              },
            ),
            const SizedBox(height: 12),
            // Цель
            _field(
              controller: _targetCtrl,
              label: 'Цель (дней)',
              hint: '30',
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Введите число > 0';
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Кнопка
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: const Color(0xFF7C3AED).withOpacity(0.5),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Создать',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRepeatTypeLabel(HabitRepeatType type) {
    return switch (type) {
      HabitRepeatType.everyDay => 'Ежедневно',
      HabitRepeatType.specificDaysOfWeek => 'Дни недели',
      HabitRepeatType.specificDaysOfMonth => 'Дни месяца',
      HabitRepeatType.xTimesPerPeriod => 'X раз в период',
    };
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}