class DownloadHistory {
  final int? id;
  final String title;
  final String url;
  final String thumbnailUrl;
  final String filePath;
  final DateTime downloadTime;
  final bool isPlaylist;

  DownloadHistory({
    this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.filePath,
    required this.downloadTime,
    this.isPlaylist = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'filePath': filePath,
      'downloadTime': downloadTime.toIso8601String(),
      'isPlaylist': isPlaylist ? 1 : 0,
    };
  }

  factory DownloadHistory.fromMap(Map<String, dynamic> map) {
    return DownloadHistory(
      id: map['id'],
      title: map['title'],
      url: map['url'],
      thumbnailUrl: map['thumbnailUrl'],
      filePath: map['filePath'],
      downloadTime: DateTime.parse(map['downloadTime']),
      isPlaylist: map['isPlaylist'] == 1,
    );
  }
}