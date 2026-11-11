import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart'; // Возвращаем пакет для мобильных

class BackupService {
  /// Собирает все данные из SharedPreferences и делится ими
  static Future<void> exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, dynamic> data = {};

    for (final key in keys) {
      final value = prefs.get(key);
      if (key.startsWith('diary_') || 
          key.startsWith('user_recipes_') || 
          key.startsWith('checklist_') || 
          key.startsWith('shopping_')) {
        
        if (value is String) {
          data[key] = value;
        } else if (value is List<String>) {
          data[key] = value;
        } else if (value is int) {
          data[key] = value;
        } else if (value is bool) {
          data[key] = value;
        } else if (value is double) {
          data[key] = value;
        }
      }
    }

    if (data.isEmpty) {
      throw Exception('Нет данных для сохранения');
    }

    final jsonString = jsonEncode(data);
    
    // --- ГЕНЕРАЦИЯ ИМЕНИ ФАЙЛА ---
    final now = DateTime.now();
    final dateStr = '${now.year}_'
        '${now.month.toString().padLeft(2, '0')}_'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}';
    final fileName = '${dateStr}_backup.json';
    // -----------------------------

    XFile xFile;

    if (kIsWeb) {
      // Для Chrome (веб) используем байты
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      xFile = XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: fileName,
      );
    } else {
      // Для Android создаем реальный файл (это гарантирует правильное имя)
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);
      xFile = XFile(file.path);
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: 'Резервная копия "В балансе"',
        text: 'Файл с вашими рецептами и дневником. Дата: $dateStr',
      ),
    );
  }

  /// Загружает данные из выбранного JSON файла
  static Future<bool> importData() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    
    if (result.isEmpty) return false;

    final file = result.first;
    if (file.path == null) return false;

    final f = File(file.path!);
    final bytes = await f.readAsBytes();
    
    final jsonString = utf8.decode(bytes);
    final Map<String, dynamic> data = jsonDecode(jsonString);

    final prefs = await SharedPreferences.getInstance();
    
    // Очищаем старые данные
    final keysToRemove = prefs.getKeys().where((k) => 
      k.startsWith('diary_') || 
      k.startsWith('user_recipes_') || 
      k.startsWith('checklist_') || 
      k.startsWith('shopping_')
    ).toList();
    
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    // Записываем новые
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is List) {
        await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    }
    return true;
  }
}