class UsageLog {
  const UsageLog({
    required this.userId,
    required this.feature,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.estimatedCostUsd,
  });

  final String userId;
  final String feature;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final double estimatedCostUsd;
}
