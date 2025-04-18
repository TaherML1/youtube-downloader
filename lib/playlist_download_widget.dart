import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaylistDownloadWidget extends StatefulWidget {
  const PlaylistDownloadWidget({super.key});

  @override
  _PlaylistDownloadWidgetState createState() => _PlaylistDownloadWidgetState();
}

class _PlaylistDownloadWidgetState extends State<PlaylistDownloadWidget> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _startIndexController = TextEditingController();
  final TextEditingController _endIndexController = TextEditingController();
  String _output = '';
  String? _selectedDirectory;
  bool _isLoading = false;
  String? _playlistTitle;
  final Shell _shell = Shell();
  bool _downloadAsAudio = false;
  bool _createPlaylistFolder = true;

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

  Future<void> _fetchPlaylistInfo() async {
    if (_urlController.text.isEmpty) {
      setState(() => _output = 'Please enter a playlist URL');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Get playlist title
      var titleResult = await _shell.run('yt-dlp --get-title ${_urlController.text}');
      _playlistTitle = titleResult.outText.split('\n').first.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // Get playlist item count
      var countResult = await _shell.run('yt-dlp --flat-playlist --print "%(playlist_index)s" ${_urlController.text} | tail -n 1');
      int itemCount = int.tryParse(countResult.outText.trim()) ?? 0;

      setState(() {
        _output = 'Playlist found: $_playlistTitle\nContains $itemCount items';
        if (itemCount > 0) {
          _startIndexController.text = '1';
          _endIndexController.text = itemCount.toString();
        }
      });
    } catch (e) {
      setState(() => _output = 'Error fetching playlist info: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPlaylist() async {
    if (_selectedDirectory == null || _playlistTitle == null) return;

    setState(() => _isLoading = true);
    try {
      String rangeOption = '';
      if (_startIndexController.text.isNotEmpty && _endIndexController.text.isNotEmpty) {
        rangeOption = '--playlist-items ${_startIndexController.text}-${_endIndexController.text}';
      }

      String folderOption = _createPlaylistFolder ? '--output "$_selectedDirectory/$_playlistTitle/%(title)s.%(ext)s"' : 
                                            '--output "$_selectedDirectory/%(title)s.%(ext)s"';

      String audioOption = _downloadAsAudio ? '-x --audio-format mp3' : '';

      var command = 'yt-dlp $audioOption $rangeOption $folderOption ${_urlController.text}';

      var result = await _shell.run(command);

      setState(() {
        if (result.outText.contains('has already been downloaded')) {
          _output = 'Some items were already downloaded.';
        } else {
          _output = 'Playlist download completed successfully!';
        }
      });
    } catch (e) {
      setState(() => _output = 'Error: $e');
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
      _startIndexController.clear();
      _endIndexController.clear();
      _output = '';
      _playlistTitle = null;
      _downloadAsAudio = false;
      _createPlaylistFolder = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
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
                labelText: 'Playlist URL',
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
                    label: const Text('Fetch Playlist Info'),
                    onPressed: _fetchPlaylistInfo,
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
            if (_playlistTitle != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Playlist Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Title: $_playlistTitle'),
                      const SizedBox(height: 8),
                      Text(_output.split('\n').last),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startIndexController,
                      decoration: const InputDecoration(
                       labelText: 'Start Index (1 = first video)',
                        
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _endIndexController,
                      decoration: const InputDecoration(
                        labelText: 'End Index (last video if you want to download all list)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Download as MP3'),
                value: _downloadAsAudio,
                onChanged: (value) => setState(() => _downloadAsAudio = value),
              ),
              SwitchListTile(
                title: const Text('Create playlist folder'),
                value: _createPlaylistFolder,
                onChanged: (value) => setState(() => _createPlaylistFolder = value),
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Playlist'),
              onPressed: _downloadPlaylist,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_output.isNotEmpty)
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