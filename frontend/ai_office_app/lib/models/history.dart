// lib/models/history.dart
class HistoryItem {
  final int id;
  final String type;       // 'summary' | 'meeting' | 'email'
  final String title;
  final String content;
  final String timestamp;

  const HistoryItem({
    required this.id, required this.type,
    required this.title, required this.content,
    required this.timestamp,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id:        json['id'],
    type:      json['type'],
    title:     json['title'],
    content:   json['content'],
    timestamp: json['timestamp'],
  );
}
