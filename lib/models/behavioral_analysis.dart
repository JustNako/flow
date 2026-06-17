class BehavioralAnalysis {
  final DonutRhythm rhythm;
  final List<FrictionPattern> frictionPatterns;
  final AiPrescription aiPrescription;
  final List<int> weeklyRhythm;

  BehavioralAnalysis({
    required this.rhythm,
    required this.frictionPatterns,
    required this.aiPrescription,
    required this.weeklyRhythm,
  });

  factory BehavioralAnalysis.fromJson(Map<String, dynamic> json) {
    final frictionList = json['frictionPatterns'] as List? ?? [];
    final rhythmList = (json['weeklyRhythm'] as List?)?.map((e) => e as int).toList() ?? [];
    return BehavioralAnalysis(
      rhythm: DonutRhythm.fromJson(json['rhythm'] ?? {}),
      frictionPatterns: frictionList.map((e) => FrictionPattern.fromJson(e)).toList(),
      aiPrescription: AiPrescription.fromJson(json['aiPrescription'] ?? {}),
      weeklyRhythm: rhythmList,
    );
  }
}

class DonutRhythm {
  final int completed;
  final int partial;
  final int missed;

  DonutRhythm({
    required this.completed,
    required this.partial,
    required this.missed,
  });

  factory DonutRhythm.fromJson(Map<String, dynamic> json) {
    return DonutRhythm(
      completed: json['completed'] as int? ?? 0,
      partial: json['partial'] as int? ?? 0,
      missed: json['missed'] as int? ?? 0,
    );
  }
}

class FrictionPattern {
  final String icon;
  final String pattern;

  FrictionPattern({
    required this.icon,
    required this.pattern,
  });

  factory FrictionPattern.fromJson(Map<String, dynamic> json) {
    return FrictionPattern(
      icon: json['icon'] as String? ?? 'moon',
      pattern: json['pattern'] as String? ?? '',
    );
  }
}

class AiPrescription {
  final String text;
  final List<PrescriptionAction> actions;

  AiPrescription({
    required this.text,
    required this.actions,
  });

  factory AiPrescription.fromJson(Map<String, dynamic> json) {
    final actionsList = json['actions'] as List? ?? [];
    return AiPrescription(
      text: json['text'] as String? ?? '',
      actions: actionsList.map((e) => PrescriptionAction.fromJson(e)).toList(),
    );
  }
}

class PrescriptionAction {
  final String habitId;
  final String habitTitle;
  final String type;
  final String currentValue;
  final String newValue;
  final String actionText;
  final Map<String, dynamic> payload;

  PrescriptionAction({
    required this.habitId,
    required this.habitTitle,
    required this.type,
    required this.currentValue,
    required this.newValue,
    required this.actionText,
    required this.payload,
  });

  factory PrescriptionAction.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'] as Map<String, dynamic>? ?? {};
    final newValue = json['newValue'] as String? ?? '';
    final payload = <String, dynamic>{};
    if (rawPayload.containsKey('targetDays')) {
      final val = rawPayload['targetDays'];
      if (val is String) {
        payload['targetDays'] = _parseFirstInt(val);
      } else if (val is num) {
        final parsed = val.toInt();
        payload['targetDays'] = parsed > 0 ? parsed : null;
      }
    }
    if (payload['targetDays'] == null) {
      final parsed = _parseFirstInt(newValue);
      if (parsed != null) payload['targetDays'] = parsed;
    }
    if (rawPayload.containsKey('timeOfDay')) {
      payload['timeOfDay'] = rawPayload['timeOfDay']?.toString();
    }
    if (payload['timeOfDay'] == null) {
      final parsedTime = _parseTimeOfDay(newValue);
      if (parsedTime != null) payload['timeOfDay'] = parsedTime;
    }

    return PrescriptionAction(
      habitId: json['habitId']?.toString() ?? '',
      habitTitle: json['habitTitle'] as String? ?? '',
      type: json['type'] as String? ?? '',
      currentValue: json['currentValue'] as String? ?? '',
      newValue: json['newValue'] as String? ?? '',
      actionText: json['actionText'] as String? ?? '',
      payload: payload,
    );
  }

  int? resolvedTargetDays() => payload['targetDays'] as int?;

  String? resolvedTimeOfDay() => payload['timeOfDay'] as String?;

  static int? _parseFirstInt(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return null;
    final parsed = int.tryParse(match.group(0)!);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String? _parseTimeOfDay(String value) {
    final match24 = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(value);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1)!);
      final minute = int.tryParse(match24.group(2)!);
      if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }

    final match12 = RegExp(r'\b(\d{1,2})\s*(am|pm)\b', caseSensitive: false).firstMatch(value);
    if (match12 != null) {
      var hour = int.tryParse(match12.group(1)!);
      if (hour == null) return null;
      final isPm = match12.group(2)!.toLowerCase() == 'pm';
      if (hour == 12) {
        hour = isPm ? 12 : 0;
      } else if (isPm) {
        hour += 12;
      }
      return '${hour.toString().padLeft(2, '0')}:00';
    }

    return null;
  }
}
