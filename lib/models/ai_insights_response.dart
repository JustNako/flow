class AiInsightsResponse {
  final List<String> insights;
  final bool isPersonalized;
  final String? message;

  const AiInsightsResponse({
    required this.insights,
    required this.isPersonalized,
    this.message,
  });

  factory AiInsightsResponse.fromJson(dynamic json) {
    // Legacy: API used to return a bare JSON array of strings
    if (json is List) {
      return AiInsightsResponse(
        insights: json.map((e) => e.toString()).toList(),
        isPersonalized: true,
      );
    }

    final map = json as Map<String, dynamic>;
    final rawInsights = map['insights'];
    return AiInsightsResponse(
      insights: rawInsights is List
          ? rawInsights.map((e) => e.toString()).toList()
          : const [],
      isPersonalized: map['isPersonalized'] as bool? ?? false,
      message: map['message'] as String?,
    );
  }
}
