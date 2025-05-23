import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'data.db');

    final exists = await File(path).exists();
    if (!exists) {
      final data = await rootBundle.load('assets/data.db');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(path);
  }

  static Future<List<Map<String, dynamic>>> queryData(String field, String value) async {
    final db = await database;
    return await db.query(
      'padron',
      where: '$field = ?',
      whereArgs: [value],
    );
  }

  static Future<List<Map<String, dynamic>>> queryByName(String name) async {
    final db = await database;
    return await db.query(
      'padron',
      where: 'LOWER(`NOMBRE COMPLETO`) LIKE ?',
      whereArgs: ['%${name.toLowerCase()}%'],
    );
  }

  static Future<void> updateDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'data.db');

    // Replace this part with actual download code if available
    final data = await rootBundle.load('assets/data.db');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  static Future<void> saveComment(Map<String, dynamic> record, String comment) async {
    final db = await database;
    await db.insert(
      'comentarios',
      {
        'cedula': record['CEDULA'],
        'nombre': record['NOMBRE COMPLETO'],
        'comunidad': record['COMUNIDAD'],
        'comentario': comment,
        'fecha': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedComments() async {
    final db = await database;
    return await db.query(
      'comentarios',
      where: 'sincronizado = 0',
    );
  }

  static Future<void> updateComment(int id, String comentario) async {
    final db = await database;
    await db.update(
      'comentarios',
      {'comentario': comentario},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> uploadComments() async {
    final db = await database;
    await db.update(
      'comentarios',
      {'sincronizado': 1},
      where: 'sincronizado = 0',
    );
  }
  static Future<bool> checkUnsyncedComments() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM comentarios WHERE sincronizado = 0');
    final count = Sqflite.firstIntValue(result);
    return count != null && count > 0;
  }

}
