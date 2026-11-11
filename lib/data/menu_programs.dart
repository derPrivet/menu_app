class MenuProgram {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final List<ProgramSlot> slots;

  const MenuProgram({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.slots,
  });
}

class ProgramSlot {
  final String label; // 'Завтрак', 'Перекус 1'...
  final String recipeId; // ссылка на Recipe.id
  final String? extra; // доп. инфо (напиток, вода и т.д.)

  const ProgramSlot({required this.label, required this.recipeId, this.extra});
}

const List<MenuProgram> menuPrograms = [
  MenuProgram(
    id: 'lymph',
    title: 'Меню для запуска лимфы',
    emoji: '💧',
    description:
        'Помогает мягко запустить лимфоток, снять отёки и улучшить самочувствие. 4 приёма пищи.',
    slots: [
      ProgramSlot(
        label: 'Завтрак',
        recipeId: 'syrniki_vishnya',
        extra: '+ зелёный чай или отвар шиповника',
      ),
      ProgramSlot(label: 'Перекус 1', recipeId: 'smuzi_kefir_frukty'),
      ProgramSlot(label: 'Обед', recipeId: 'sup_brokkoli'),
      ProgramSlot(label: 'Перекус 2', recipeId: 'smuzi_kefir_frukty'),
      ProgramSlot(
        label: 'Ужин',
        recipeId: 'indeyka_ris_salat',
        extra: '+ стакан воды «Ессентуки №4» за 30 минут до еды',
      ),
    ],
  ),
  MenuProgram(
    id: 'hormones',
    title: 'Меню для гормонального фона',
    emoji: '🌸',
    description:
        'Сбалансированное питание для поддержки гормонов. Подходит при ПМС, инсулинорезистентности, гормональных сбоях.',
    slots: [
      ProgramSlot(label: 'Завтрак', recipeId: 'omlet_krasnaya_ryba'),
      ProgramSlot(label: 'Перекус 1', recipeId: 'salat_frukty_syr'),
      ProgramSlot(label: 'Обед', recipeId: 'salat_kurica_chernosliv'),
      ProgramSlot(label: 'Перекус 2', recipeId: 'kefir_yogurt'),
      ProgramSlot(label: 'Ужин', recipeId: 'sardelki_naturalnye'),
    ],
  ),
  MenuProgram(
    id: 'detox',
    title: 'Меню для детокса организма',
    emoji: '🧬',
    description:
        'Мягкое очищение и поддержка кишечника. Богато клетчаткой и пробиотиками.',
    slots: [
      ProgramSlot(label: 'Завтрак', recipeId: 'ovsyanka_frukty'),
      ProgramSlot(label: 'Перекус 1', recipeId: 'kislomolochka_len'),
      ProgramSlot(label: 'Обед', recipeId: 'krupa_ryba_salat'),
      ProgramSlot(label: 'Перекус 2', recipeId: 'kislomolochka_len'),
      ProgramSlot(
        label: 'Ужин',
        recipeId: 'krupa_ryba_salat',
        extra: 'Полностью повторяет обед',
      ),
    ],
  ),
];
