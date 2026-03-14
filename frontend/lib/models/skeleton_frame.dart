class SkeletonFrame {
  final String skeletonUrl;
  final String label;
  final int delayMs;

  SkeletonFrame({
    required this.skeletonUrl,
    required this.label,
    required this.delayMs,
  });

  // This factory takes the Python JSON dict and converts it to a Dart Object
  factory SkeletonFrame.fromJson(Map<String, dynamic> json) {
    return SkeletonFrame(
      skeletonUrl: json['skeleton_url'] ?? '',
      label: json['label'] ?? '',
      delayMs: json['delay_ms'] ?? 0,
    );
  }
}

class ProcessResponse {
  final String mode;
  final List<SkeletonFrame> data;

  ProcessResponse({required this.mode, required this.data});

  factory ProcessResponse.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List? ?? [];
    List<SkeletonFrame> dataList = list.map((i) => SkeletonFrame.fromJson(i)).toList();

    return ProcessResponse(
      mode: json['mode'] ?? 'unknown',
      data: dataList,
    );
  }
}