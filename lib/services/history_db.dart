import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/download_history.dart';

class HistoryDatabase {
 static final HistoryDatabase instance = HistoryDatabase._init();
  static Database? _database;

 
  HistoryDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('download_history.db');
    return _database!;
  }

 Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE download_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        thumbnailUrl TEXT NOT NULL,
        filePath TEXT NOT NULL,
        downloadTime TEXT NOT NULL,
        isPlaylist INTEGER NOT NULL
      )
    ''');
  }

  Future<int> addHistory(DownloadHistory history) async {
    final db = await instance.database;
    return await db.insert('download_history', history.toMap());
  }

  Future<List<DownloadHistory>> getAllHistory() async {
    final db = await instance.database;
    final maps = await db.query('download_history', orderBy: 'downloadTime DESC');
    return maps.map((map) => DownloadHistory.fromMap(map)).toList();
  }

  Future<int> deleteHistory(int id) async {
    final db = await instance.database;
    return await db.delete(
      'download_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}