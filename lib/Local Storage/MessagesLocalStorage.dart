import 'package:glamora/models/MessagingModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'messages.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            message TEXT,
            time TEXT,
            date TEXT,
            isSender INTEGER,
            status TEXT,
            reaction TEXT,
            repliedTo TEXT,
            repliedMessage TEXT,
            repliedType TEXT,
            messageType TEXT,
            localPath TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertMessage(MessageModel message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageModel>> getMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('messages');
    return List.generate(maps.length, (i) {
      return MessageModel.fromMap(maps[i], id: maps[i]['id']);
    });
  }

  Future<List<MessageModel>> getPendingMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'status IN (?, ?, ?)',
      whereArgs: ['pending', 'uploading', 'sending'],
    );
    return List.generate(maps.length, (i) {
      return MessageModel.fromMap(maps[i], id: maps[i]['id']);
    });
  }

  Future<void> updateMessageStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMessageUrl(String id, String url, {String? localPath}) async {
    final db = await database;
    await db.update(
      'messages',
      {
        'message': url,
        if (localPath != null) 'localPath': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // New method to delete a message by ID
  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // New method to get a message by ID
  Future<MessageModel?> getMessageById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return MessageModel.fromMap(maps.first, id: maps.first['id']);
    }
    return null;
  }
}