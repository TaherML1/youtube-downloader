import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../models/download_history.dart';
import '../services/history_db.dart';
import 'package:youtube_downloader/HistoryScreen.dart';

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
  bool _isFetching = false;
  String? _playlistTitle;
  final Shell _shell = Shell();
  bool _downloadAsAudio = false;
  bool _createPlaylistFolder = true;
  String? _thumbnailUrl;

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

  String? _extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})'
    );
    return regExp.firstMatch(url)?.group(1);
  }

  Future<void> _fetchPlaylistInfo() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a playlist URL')),
      );
      return;
    }

    setState(() {
      _isFetching = true;
      _thumbnailUrl = null;
    });

    try {
      final videoId = _extractVideoId(_urlController.text);
      if (videoId != null) {
        setState(() => _thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg');
      }

      var titleResult = await _shell.run('yt-dlp --get-title ${_urlController.text}');
      _playlistTitle = titleResult.outText.split('\n').first.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      var countResult = await _shell.run('yt-dlp --flat-playlist --print "%(playlist_index)s" ${_urlController.text} | tail -n 1');
      int itemCount = int.tryParse(countResult.outText.trim()) ?? 0;

      setState(() {
        if (itemCount > 0) {
          _startIndexController.text = '1';
          _endIndexController.text = itemCount.toString();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _saveDownloadHistory(String filePath) async {
    if (_playlistTitle == null || _urlController.text.isEmpty) return;

    final history = DownloadHistory(
      title: _playlistTitle!,
      url: _urlController.text,
      thumbnailUrl: _thumbnailUrl ?? '',
      filePath: filePath,
      downloadTime: DateTime.now(),
      isPlaylist: true,
    );

    await HistoryDatabase.instance.addHistory(history);
  }

  Future<void> _downloadPlaylist() async {
    if (_selectedDirectory == null || _playlistTitle == null) return;

    setState(() => _isLoading = true);
    try {
      String rangeOption = '';
      if (_startIndexController.text.isNotEmpty && _endIndexController.text.isNotEmpty) {
        rangeOption = '--playlist-items ${_startIndexController.text}-${_endIndexController.text}';
      }

      final savePath = _createPlaylistFolder
          ? '$_selectedDirectory/$_playlistTitle'
          : _selectedDirectory!;

      String folderOption = '--output "$savePath/%(title)s.%(ext)s"';
      String audioOption = _downloadAsAudio ? '-x --audio-format mp3' : '';

      var command = 'yt-dlp $audioOption $rangeOption $folderOption ${_urlController.text}';
      var result = await _shell.run(command);

      if (result.outText.contains('has already been downloaded')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Some items were already downloaded')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist download completed!')),
        );
        _saveDownloadHistory(savePath);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
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
      _playlistTitle = null;
      _thumbnailUrl = null;
      _downloadAsAudio = false;
      _createPlaylistFolder = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: (){
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _resetFields,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Playlist URL',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _isLoading ? null : () async {
                      final clipboard = await Clipboard.getData('text/plain');
                      if (clipboard != null) {
                        _urlController.text = clipboard.text ?? '';
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_thumbnailUrl != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(_thumbnailUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isFetching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isFetching ? 'Fetching...' : 'Fetch Info'),
                      onPressed: _isFetching || _isLoading ? null : _fetchPlaylistInfo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Folder'),
                      onPressed: _isLoading ? null : _pickDirectory,
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
                        Text(
                          _playlistTitle!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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
                          labelText: 'Start Index (1)',
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
                          labelText: 'End Index',
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
                  onChanged: _isLoading ? null : (value) => setState(() => _downloadAsAudio = value),
                ),
                SwitchListTile(
                  title: const Text('Create playlist folder'),
                  value: _createPlaylistFolder,
                  onChanged: _isLoading ? null : (value) => setState(() => _createPlaylistFolder = value),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isLoading ? 'Downloading...' : 'Download Playlist'),
                  onPressed: _isLoading ? null : _downloadPlaylist,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
