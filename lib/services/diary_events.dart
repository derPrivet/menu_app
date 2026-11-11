import 'package:flutter/foundation.dart';

/// Уведомляет об изменениях в дневнике.
/// Инкрементируется при добавлении/удалении записи из ЛЮБОГО места приложения.
/// DiaryTab слушает и перезагружает данные.
final diaryVersionNotifier = ValueNotifier<int>(0);

void notifyDiaryChanged() {
  diaryVersionNotifier.value++;
}
