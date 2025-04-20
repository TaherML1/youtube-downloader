import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/download_history.dart';
import '../services/history_db.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<DownloadHistory>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = HistoryDatabase.instance.getAllHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: FutureBuilder<List<DownloadHistory>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No download history yet'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final item = snapshot.data![index];
              return _buildHistoryItem(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(DownloadHistory item) {
  return Dismissible(
    key: Key(item.id.toString()),
    background: Container(color: Colors.red),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => _deleteItem(item.id!),
    child: Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: CachedNetworkImage(
          imageUrl: item.thumbnailUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
       subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      DateFormat('MMM dd, yyyy - hh:mm a').format(item.downloadTime),
    ),
    Text(
      item.isPlaylist ? 'Playlist' : 'Video',
      style: TextStyle(color: Colors.grey[600]),
    ),
  ],
),

        trailing: IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => _openFile(item.filePath),
        ),
      ),
    ),
  );
}

  Future<void> _openFile(String path) async {
    // Implement file opening logic (using url_launcher or native plugins)
  }

  Future<void> _deleteItem(int id) async {
    await HistoryDatabase.instance.deleteHistory(id);
    _refreshHistory();
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This cannot be undone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await HistoryDatabase.instance.database;
      await db.delete('download_history');
      _refreshHistory();
    }
  }
}