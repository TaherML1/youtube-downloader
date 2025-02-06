import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/AudioDownloadWidget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'youtube downloader',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      home: YtDlpIntegration(),
    );
  }
}

class YtDlpIntegration extends StatefulWidget {
  @override
  _YtDlpIntegrationState createState() => _YtDlpIntegrationState();
}

class _YtDlpIntegrationState extends State<YtDlpIntegration> {
  final TextEditingController _urlController = TextEditingController();
  String _output = '';
  String? _selectedDirectory;
  List<String> _videoFormats = [];
  List<String> _audioFormats = [];
  String? _selectedVideoFormat;
  String? _selectedAudioFormat;
  bool _isLoading = false;
  String? _videoTitle;
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

  Future<void> _fetchFormats() async {
    if (_urlController.text.isEmpty) {
      setState(() => _output = 'Please enter a URL');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Get video title
      var titleResult = await _shell.run('yt-dlp --get-title ${_urlController.text}');
      _videoTitle = titleResult.outText.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // Get formats
      var result = await _shell.run('yt-dlp -F ${_urlController.text}');
      List<String> formats = result.outText.split('\n');

      // Parse formats with extension detection
      _videoFormats = formats.where((line) {
        return line.contains('video only') && 
               line.trim().isNotEmpty &&
               !line.contains('av01');
      }).map((line) {
        var parts = line.split(RegExp(r'\s+'));
        return '${parts[0]} (${parts.last})'; // Format code + extension
      }).toList();

      _audioFormats = formats.where((line) {
        return line.contains('audio only') && 
               line.trim().isNotEmpty &&
               !line.contains('video');
      }).map((line) {
        var parts = line.split(RegExp(r'\s+'));
        return '${parts[0]} (${parts.last})'; // Format code + extension
      }).toList();

      setState(() => _output = 'Formats fetched successfully');
    } catch (e) {
      setState(() => _output = 'Error fetching formats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

 Future<void> _downloadVideo() async {
  if (_selectedDirectory == null || _videoTitle == null) return;

  setState(() => _isLoading = true);
  try {
    // Extract format codes and extensions
    final videoCode = _selectedVideoFormat!.split(' ').first;
    final audioCode = _selectedAudioFormat!.split(' ').first;
    final videoExt = _selectedVideoFormat!.split('(').last.replaceAll(')', '').trim();
    final audioExt = _selectedAudioFormat!.split('(').last.replaceAll(')', '').trim();

    // Download and merge in one command
    var result = await _shell.run(
      'yt-dlp -f $videoCode+$audioCode '
      '-o "$_selectedDirectory/$_videoTitle.%(ext)s" '
      '${_urlController.text}'
    );

    // Check if video is already downloaded
    if (result.outText.contains('has already been downloaded')) {
      setState(() => _output = 'Video has already been downloaded.');
    } else {
      setState(() => _output = 'Download and merge completed successfully!');
    }
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
      _selectedVideoFormat = null;
      _selectedAudioFormat = null;
      _output = '';
      _videoTitle = null;
    });
  }

  @override
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('youtube video downloader'),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: _resetFields,
        ),
        IconButton(
          icon: Icon(Icons.music_note),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AudioDownloadWidget()),
            );
          },
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Video URL',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.search),
                  label: Text('Fetch Formats'),
                  onPressed: _fetchFormats,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.folder_open),
                  label: Text('Select Directory'),
                  onPressed: _pickDirectory,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_videoFormats.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Video Format',
                border: OutlineInputBorder(),
              ),
              value: _selectedVideoFormat,
              items: _videoFormats.map((format) => DropdownMenuItem(
                value: format,
                child: Text(format),
              )).toList(),
              onChanged: (value) => setState(() => _selectedVideoFormat = value),
            ),
          SizedBox(height: 10),
          if (_audioFormats.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
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
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.download),
            label: Text('Download & Merge'),
            onPressed: _downloadVideo,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          SizedBox(height: 20),
          if (_isLoading)
            Center(child: CircularProgressIndicator())
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(_output, style: TextStyle(color: Colors.green)),
                    if (_selectedDirectory != null) ...[
                      SizedBox(height: 12),
                      Text('Download Directory:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_selectedDirectory!),
                    ],
                    if (_videoTitle != null) ...[
                      SizedBox(height: 12),
                      Text('Video Title:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_videoTitle!),
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