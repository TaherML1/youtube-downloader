import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AudioDownloadWidget extends StatefulWidget {
  const AudioDownloadWidget({super.key});

  @override
  _AudioDownloadWidgetState createState() => _AudioDownloadWidgetState();
}

class _AudioDownloadWidgetState extends State<AudioDownloadWidget> {
  final TextEditingController _urlController = TextEditingController();
  String _output = '';
  String? _selectedDirectory;
  List<String> _audioFormats = [];
  String? _selectedAudioFormat;
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

  Future<void> _fetchAudioFormats() async {
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

      // Parse audio formats
      _audioFormats = formats.where((line) {
        return line.contains('audio only') && line.trim().isNotEmpty;
      }).map((line) {
        var parts = line.split(RegExp(r'\s+'));
        return '${parts[0]} (${parts.last})'; // Format code + extension
      }).toList();

      setState(() => _output = 'Audio formats fetched successfully');
    } catch (e) {
      setState(() => _output = 'Error fetching audio formats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadAudio() async {
    if (_selectedDirectory == null || _audioTitle == null) return;

    setState(() => _isLoading = true);
    try {
      // Extract format code and extension
      final audioCode = _selectedAudioFormat!.split(' ').first;
      final audioExt = _selectedAudioFormat!.split('(').last.replaceAll(')', '').trim();

      // Download audio
      await _shell.run(
        'yt-dlp -f $audioCode '
        '-o "$_selectedDirectory/$_audioTitle.$audioExt" '
        '${_urlController.text}'
      );

      setState(() => _output = 'Audio download completed successfully!');
    } catch (e) {
      setState(() => _output = 'Error: $e\nTry different format combinations');
    } finally {
      setState(() => _isLoading = false);
    }
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
      _selectedAudioFormat = null;
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
                    icon: const Icon(Icons.search),
                    label: const Text('Fetch Audio Formats'),
                    onPressed: _fetchAudioFormats,
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
            if (_audioFormats.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Audio Format',
                  border: OutlineInputBorder(),
                ),
                value: _selectedAudioFormat,
                items: _audioFormats.map((format) => DropdownMenuItem(
                  value: format,
                  child: Text(format),
                )).toList(),
                onChanged: (value) => setState(() => _selectedAudioFormat = value),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Audio'),
              onPressed: _downloadAudio,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
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
