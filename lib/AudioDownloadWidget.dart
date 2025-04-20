import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_history.dart'; // Ensure this path is correct
import '../services/history_db.dart'; // Ensure this path is correct

class AudioDownloadWidget extends StatefulWidget {
  const AudioDownloadWidget({super.key});

  @override
  _AudioDownloadWidgetState createState() => _AudioDownloadWidgetState();
}

class _AudioDownloadWidgetState extends State<AudioDownloadWidget> {
  final TextEditingController _urlController = TextEditingController();
  String _output = '';
  String? _selectedDirectory;
  bool _isLoading = false;
  String? _audioTitle;
  final Shell _shell = Shell();

  @override
  void initState() {
    super.initState();
    _loadSavedDirectory();
  }

  Future<void> _loadSavedDirectory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _selectedDirectory = prefs.getString('download_directory'));
  }

  Future<void> _saveDirectory(String directory) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_directory', directory);
  }

  Future<void> _fetchAndDownloadAudio() async {
    if (_urlController.text.isEmpty) {
      setState(() => _output = 'Please enter a URL');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Get audio title
      var titleResult = await _shell.run('yt-dlp --get-title ${_urlController.text}');
      _audioTitle = titleResult.outText.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // Get audio formats
      var result = await _shell.run('yt-dlp -F ${_urlController.text}');
      List<String> formats = result.outText.split('\n');

      // Find the best audio format (e.g., highest bitrate mp3 or m4a)
      String? bestAudioFormat;
      for (var line in formats) {
        if (line.contains('audio only') && line.trim().isNotEmpty) {
          var parts = line.split(RegExp(r'\s+'));
          var formatCode = parts[0];
          var extension = parts.last.contains('mp3') ? 'mp3' : 'm4a';
          bestAudioFormat = '$formatCode ($extension)';
          break; // Take the first suitable format found
        }
      }

      if (bestAudioFormat == null) {
        setState(() => _output = 'No suitable audio format found');
        return;
      }

      // Extract format code and extension
      final audioCode = bestAudioFormat.split(' ').first;
      final audioExt = bestAudioFormat.split('(').last.replaceAll(')', '').trim();

      // Construct file path
      final filePath = '$_selectedDirectory/$_audioTitle.$audioExt';

      // Download audio
      await _shell.run(
        'yt-dlp -f $audioCode '
        '-o "$filePath" '
        '${_urlController.text}'
      );

      setState(() => _output = 'Audio download completed successfully!');

      // Save download history
      await _saveDownloadHistory(filePath);
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDownloadHistory(String filePath) async {
    if (_audioTitle == null || _urlController.text.isEmpty) return;

    final history = DownloadHistory(
      title: _audioTitle!,
      url: _urlController.text,
      thumbnailUrl: '', // Assuming no thumbnail for audio
      filePath: filePath,
      downloadTime: DateTime.now(),
      isPlaylist: false,
    );

    await HistoryDatabase.instance.addHistory(history);
  }

  Future<void> _pickDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _selectedDirectory = result);
      _saveDirectory(result);
    }
  }

  void _resetFields() {
    setState(() {
      _urlController.clear();
      _selectedDirectory = null;
      _output = '';
      _audioTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetFields,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Audio URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isLoading ? 'Downloading...' : 'Download Audio'),
                    onPressed: _isLoading ? null : _fetchAndDownloadAudio,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Directory'),
                    onPressed: _pickDirectory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_output, style: const TextStyle(color: Colors.green)),
                      if (_selectedDirectory != null) ...[
                        const SizedBox(height: 12),
                        const Text('Download Directory:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_selectedDirectory!),
                      ],
                      if (_audioTitle != null) ...[
                        const SizedBox(height: 12),
                        const Text('Audio Title:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_audioTitle!),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
