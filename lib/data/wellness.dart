class WellnessSection {
  final String title;
  final String emoji;
  final List<WellnessBlock> blocks;

  const WellnessSection({
    required this.title,
    required this.emoji,
    required this.blocks,
  });
}

class WellnessBlock {
  final String heading;
  final String? body;
  final List<String>? bullets;
  final List<ProductSource>? products;

  const WellnessBlock({
    required this.heading,
    this.body,
    this.bullets,
    this.products,
  });
}

class ProductSource {
  final String emoji;
  final String name;

  const ProductSource(this.emoji, this.name);
}

const List<WellnessSection> wellnessSections = [
  WellnessSection(
    title: 'Всё о клетчатке',
    emoji: '🌾',
    blocks: [
      WellnessBlock(
        heading: 'Что это и зачем',
        body:
            'Клетчатка — главный продукт для правильной работы кишечника. Она улучшает моторику, восстанавливает микрофлору, борется с запорами, метеоризмом и вздутием.',
        bullets: [
          'Способствует детоксикации — выводит вредные соединения',
          'Снижает гликемический индекс углеводов (нет скачков сахара)',
          'Понижает холестерин и уровень сахара в крови',
          'Даёт сытость и поддерживает стройность',
          'Укрепляет иммунитет',
        ],
      ),
      WellnessBlock(
        heading: 'Норма потребления',
        body:
            'Медицинская норма — 25–30 г в день, но многие врачи рекомендуют до 40 г. В США норма пересмотрена до 50 г. Среднестатистический россиянин съедает всего 10–15 г в день — это в 2–3 раза меньше нормы.',
      ),
      WellnessBlock(
        heading: 'Растворимая клетчатка',
        body:
            'При расщеплении образует гель, обволакивающий стенки кишечника. Замедляет пищеварение, снижает холестерин, выводит тяжёлые металлы и токсины.',
        bullets: [
          'Пектин, гемицеллюлоза, камедь, слизь',
          'Галактоолигосахариды, фруктоолигосахариды, инулин',
        ],
      ),
      WellnessBlock(
        heading: 'Нерастворимая клетчатка',
        body:
            'Не растворяется в воде, не переваривается. Проходит по ЖКТ почти в неизменном виде, ускоряет проход пищи, размягчает стул. Отличное средство от запоров.',
        bullets: [
          'Целлюлоза, гемицеллюлоза, лигнин',
          'Источники: кожица ягод, оболочка цельного зерна, отруби',
        ],
      ),
    ],
  ),
  WellnessSection(
    title: 'Продукты-чемпионы',
    emoji: '🏆',
    blocks: [
      WellnessBlock(
        heading: 'Инулин',
        body:
            'Один из видов фруктоолигосахаридов. В диетологии — пребиотик: кормит полезные бактерии кишечника.',
        products: [
          ProductSource('🌱', 'Топинамбур'),
          ProductSource('🧄', 'Лук'),
          ProductSource('🍌', 'Банан'),
          ProductSource('🍇', 'Изюм'),
          ProductSource('🌿', 'Спаржа'),
          ProductSource('🌰', 'Артишок'),
          ProductSource('🥕', 'Цикорий (лидер)'),
        ],
      ),
      WellnessBlock(
        heading: 'Пектин',
        body: 'Питательный субстрат для «хороших» бактерий кишечника.',
        products: [
          ProductSource('🫐', 'Чёрная смородина'),
          ProductSource('🍎', 'Яблоки'),
          ProductSource('🍒', 'Слива'),
          ProductSource('🍑', 'Абрикосы'),
          ProductSource('🍇', 'Крыжовник'),
          ProductSource('🎃', 'Тыква'),
          ProductSource('🧧', 'Свёкла'),
        ],
      ),
      WellnessBlock(
        heading: 'Галактоолигосахариды',
        body:
            'Стимулируют работу кишечника, поддерживают пищеварение. При недостатке — дисбактериоз, колит, вздутие. Норма ~15 г в сутки.',
        products: [
          ProductSource('🥛', 'Молочные продукты'),
          ProductSource('🌱', 'Топинамбур'),
          ProductSource('🫘', 'Соя'),
          ProductSource('🧄', 'Чеснок'),
          ProductSource('🧅', 'Лук'),
          ProductSource('🌿', 'Спаржа'),
          ProductSource('🍅', 'Помидоры'),
          ProductSource('🥬', 'Лук-порей'),
          ProductSource('🌰', 'Артишок, цикорий'),
          ProductSource('🍌', 'Бананы'),
          ProductSource('🍇', 'Ягоды'),
          ProductSource('🥭', 'Манго'),
          ProductSource('🍎', 'Яблоки'),
          ProductSource('🌾', 'Ржаные отруби'),
        ],
      ),
      WellnessBlock(
        heading: 'Фруктоолигосахариды',
        body:
            'Проходят тонкий кишечник нетронутыми. Улучшают усвоение магния и кальция, устраняют запоры, нормализуют гормональный фон.',
        products: [
          ProductSource('🥕', 'Цикорий'),
          ProductSource('🧄', 'Чеснок'),
          ProductSource('🌱', 'Топинамбур'),
          ProductSource('🥬', 'Лук-порей'),
          ProductSource('🧅', 'Репчатый лук'),
          ProductSource('🌿', 'Зелень одуванчика'),
          ProductSource('🍌', 'Бананы'),
          ProductSource('🌊', 'Водоросли'),
          ProductSource('🌰', 'Спаржа'),
          ProductSource('🍬', 'Сахарная свёкла'),
          ProductSource('🍯', 'Мёд'),
          ProductSource('🍅', 'Помидоры'),
        ],
      ),
    ],
  ),
  WellnessSection(
    title: 'Детокс-напитки',
    emoji: '🥤',
    blocks: [
      WellnessBlock(
        heading: 'Как принимать',
        body:
            'В течение месяца чередуйте не более 2 видов напитков. Например, в первую и третью недели — «Напиток из фруктов и специй», во вторую и четвёртую — «Смузи из фруктов и зелёного чая». В следующем месяце выберите два других варианта.',
      ),
      WellnessBlock(
        heading: 'Внимание',
        body:
            'При индивидуальной непереносимости, аллергических реакциях или противопоказаниях к ингредиентам — употребляйте с осторожностью или воспользуйтесь другими рецептами.',
      ),
    ],
  ),
];
