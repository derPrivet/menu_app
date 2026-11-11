import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz_time;
import 'models/recipe.dart';
import 'data/recipes_breakfast.dart';
import 'data/recipes_lunch.dart';
import 'data/recipes_dinner.dart';
import 'data/recipes_snack.dart';
import 'data/recipes_dessert.dart';
import 'data/recipes_drink.dart';
import 'data/menu_programs.dart';
import 'data/wellness.dart';
import 'data/marathon_data.dart';
import 'models/meal_option.dart';
import 'models/marathon_program.dart';
import 'services/checklist_storage.dart';
import 'services/user_recipe_storage.dart';
import 'services/backup_service.dart';
import 'services/diary_events.dart';
import 'services/notification_service.dart';
import 'widgets/recipe_card.dart';
import 'widgets/my_products_screen.dart';
import 'widgets/diary_tab.dart';
import 'widgets/planner_tab.dart';
import 'widgets/progress_tab.dart';
import 'widgets/add_to_diary_sheet.dart';
import 'widgets/add_recipe_screen.dart';
import 'widgets/profile_screen.dart';
// import 'widgets/reminders_screen.dart';
import 'theme/app_colors.dart';

// ============ ГРАДИЕНТЫ ============
const _accentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFC05A3F), Color(0xFFE07A5F)],
);

const _greenGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2D6E4F), Color(0xFF3F8F6B)],
);

const _headerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFD96A4F), Color(0xFFE07A5F), Color(0xFFF2A488)],
);

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  tz_time.setLocalLocation(
    tz_time.getLocation('Asia/Yekaterinburg'),
  ); // <-- Уфа (UTC+5)

  await NotificationService.init();

  runApp(const MenuApp());
}

final List<Recipe> allRecipes = [
  ...breakfastRecipes,
  ...lunchRecipes,
  ...dinnerRecipes,
  ...snackRecipes,
  ...dessertRecipes,
  ...drinkRecipes,
];

class MenuApp extends StatelessWidget {
  const MenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'В балансе',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ru'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE07A5F),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF7F5F2),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE07A5F),
              brightness: Brightness.dark,
              surface: const Color(0xFF121212),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

// ============ ГЛАВНЫЙ ЭКРАН ============
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _bottomIndex = 0;
  String? _pendingRecipeId;
  int _openCounter = 0;

  bool _isBackingUp = false; // Флаг загрузки

  void _openRecipe(String recipeId) {
    setState(() {
      _bottomIndex = 0;
      _pendingRecipeId = recipeId;
      _openCounter++;
    });
  }

  void _openDrawerScreen(String title, Widget child) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DrawerScreen(title: title, child: child),
      ),
    );
  }

  // --- ЛОГИКА РЕЗЕРВНОГО КОПИРОВАНИЯ ---

  Future<void> _handleExport() async {
    setState(() => _isBackingUp = true);
    try {
      await BackupService.exportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл сформирован! Выберите, куда сохранить.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleImport() async {
    // Спрашиваем подтверждение, так как данные перезапишутся
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Загрузить копию?'),
        content: const Text(
          'Внимание! Все текущие данные (рецепты, дневник, галочки) будут заменены данными из файла.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Загрузить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBackingUp = true);
    try {
      final success = await BackupService.importData();
      if (success) {
        notifyDiaryChanged(); // Обновляем дневник
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Данные успешно загружены! Перезапустите приложение для полного обновления.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ошибка при чтении файла. Убедитесь, что это правильный файл копии.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: IndexedStack(
                index: _bottomIndex,
                children: [
                  RecipesTab(
                    openRecipeId: _pendingRecipeId,
                    openCounter: _openCounter,
                  ),
                  DiaryTab(allRecipes: allRecipes),
                  const ProgressTab(),
                  PlannerTab(
                    allRecipes: allRecipes,
                  ), // <--- Передаем список рецептов
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (i) => setState(() => _bottomIndex = i),
        backgroundColor: AppColors.cardBg(context),
        indicatorColor: AppColors.isDark(context)
            ? const Color(0xFF3A2A24)
            : const Color(0xFFFFE0D5),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Блюда',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Дневник',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Прогресс',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'План',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.cardBg(context),
      child: SafeArea(
        child: ListView(
          // <--- Заменили Column на ListView
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(gradient: _headerGradient),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🍽 В балансе',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Питание · Дневник · Здоровье',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(
              emoji: '👤',
              title: 'Мой профиль',
              subtitle: 'Данные и калькулятор калорий',
              onTap: () => _openDrawerScreen('Профиль', const ProfileScreen()),
            ),
            _drawerItem(
              emoji: '📅',
              title: 'Планы питания',
              subtitle: 'Лимфа · Гормоны · Детокс',
              onTap: () => _openDrawerScreen(
                'Планы питания',
                ProgramsTab(
                  onOpenRecipe: (id) {
                    Navigator.of(context).pop();
                    _openRecipe(id);
                  },
                ),
              ),
            ),
            _drawerItem(
              emoji: '💚',
              title: 'Здоровье',
              subtitle: 'Клетчатка, продукты, советы',
              onTap: () => _openDrawerScreen('Здоровье', const WellnessTab()),
            ),
            _drawerItem(
              emoji: '🥗',
              title: 'Мои продукты',
              subtitle: 'База ваших продуктов',
              onTap: () =>
                  _openDrawerScreen('Мои продукты', const MyProductsScreen()),
            ),
            _drawerItem(
              emoji: '🏁',
              title: 'Марафон',
              subtitle: 'Программа питания',
              onTap: () => _openDrawerScreen('Марафон', const MarathonTab()),
            ),
            _drawerItem(
              emoji: '🛒',
              title: 'Покупки',
              subtitle: 'Общий список — скоро',
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Покупки появятся в следующем обновлении'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'ДАННЫЕ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.grey,
                ),
              ),
            ),

            // Кнопки экспорта и импорта
            if (_isBackingUp)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ListTile(
                leading: const Icon(
                  Icons.upload_file,
                  color: Color(0xFF3F8F6B),
                ),
                title: Text(
                  'Сохранить копию',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                subtitle: Text(
                  'Отправить рецепты и дневник в файл',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                onTap: _handleExport,
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Color(0xFFE07A5F)),
                title: Text(
                  'Загрузить из копии',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                subtitle: Text(
                  'Восстановить данные из файла',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                onTap: _handleImport,
              ),
            ],

            // Вместо Spacer() используем просто пустое место
            const SizedBox(height: 30),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Версия 1.0 · сделано с любовью',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 22)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
      ),
      onTap: onTap,
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 12, 8, 12),
      decoration: const BoxDecoration(gradient: _headerGradient),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            tooltip: 'Меню',
            iconSize: 28,
            padding: const EdgeInsets.all(10),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🍽 В балансе',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Питание · Дневник · Здоровье',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                onPressed: () => themeModeNotifier.value = isDark
                    ? ThemeMode.light
                    : ThemeMode.dark,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: Colors.white,
                ),
                tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============ ЭКРАН ИЗ DRAWER ============
// ============ ЭКРАН ИЗ DRAWER ============
class _DrawerScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _DrawerScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Белая стрелка "назад"
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD96A4F), Color(0xFFE07A5F), Color(0xFFF2A488)],
            ),
          ),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

// ============ ВКЛАДКА «РЕЦЕПТЫ» ============
class RecipesTab extends StatefulWidget {
  final String? openRecipeId;
  final int openCounter;
  const RecipesTab({super.key, this.openRecipeId, this.openCounter = 0});

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _category = 'all';
  final Set<String> _activeFilters = {};
  final Map<String, GlobalKey> _recipeKeys = {};
  String? _justOpenedId;
  List<Recipe> _userRecipes = [];

  static const _categories = [
    ['all', 'Все'],
    ['breakfast', '🌅 Завтраки'],
    ['lunch', '🍲 Обеды'],
    ['dinner', '🌙 Ужины'],
    ['snack', '🥜 Перекусы'],
    ['dessert', '🍰 Десерты'],
    ['drink', '🥤 Напитки'],
  ];

  static const _filters = [
    ['my', '🖊 Мои'],
    ['light', '⚡ Меньше 100 Ккал/100г'],
    ['fast', '⏱ Быстро'],
    ['nocook', '🚫 Без готовки'],
    ['protein', '💪 Белок+'],
    ['fiber', '🌾 Клетчатка+'],
    ['meat', '🥩 Мясное'],
    ['fish', '🐟 Рыбное'],
    ['dairy', '🥛 Молочное'],
    ['veg', '🥦 Овощное'],
  ];

  @override
  void initState() {
    super.initState();

    allRecipes.shuffle();

    _loadUserRecipes();
    diaryVersionNotifier.addListener(_loadUserRecipes);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    diaryVersionNotifier.removeListener(_loadUserRecipes);
    super.dispose();
  }

  Future<void> _loadUserRecipes() async {
    final list = await UserRecipeStorage.loadAll();
    if (mounted) setState(() => _userRecipes = list);
  }

  List<Recipe> get _allCombined => [...allRecipes, ..._userRecipes];

  @override
  void didUpdateWidget(RecipesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCounter != oldWidget.openCounter &&
        widget.openRecipeId != null) {
      _handleOpen(widget.openRecipeId!);
    }
  }

  void _handleOpen(String recipeId) {
    setState(() {
      _searchCtrl.clear();
      _category = 'all';
      _activeFilters.clear();
      _justOpenedId = recipeId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _recipeKeys[recipeId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _justOpenedId = null);
    });
  }

  bool _matchesFilter(Recipe r, String f) {
    switch (f) {
      case 'my':
        return r.isUserRecipe;
      case 'light':
        return r.isLight;
      case 'fast':
        return r.isFast;
      case 'nocook':
        return r.noCook;
      case 'protein':
        return r.isHighProtein;
      case 'fiber':
        return r.isHighFiber;
      case 'meat':
        return r.isMeat;
      case 'fish':
        return r.isFish;
      case 'dairy':
        return r.isDairy;
      case 'veg':
        return r.isVeggie;
    }
    return true;
  }

  List<Recipe> get _filtered {
    final q = _query.toLowerCase().trim();
    return _allCombined.where((r) {
      final catOk = _category == 'all' || r.category == _category;
      final searchOk =
          q.isEmpty ||
          r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.ingredients.any((i) => i[0].toLowerCase().contains(q));
      final filtersOk = _activeFilters.every((f) => _matchesFilter(r, f));
      return catOk && searchOk && filtersOk;
    }).toList();
  }

  Future<void> _openAddRecipe({Recipe? existing}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddRecipeScreen(existing: existing)),
    );
    if (result == true) {
      _loadUserRecipes();
    }
  }

  Future<void> _deleteUserRecipe(Recipe r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить рецепт?'),
        content: Text('«${r.title}» будет удалён безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFFD35E3F)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await UserRecipeStorage.delete(r.id);
      _loadUserRecipes();
    }
  }

  void _openFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg(ctx),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border(ctx),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Фильтры',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(ctx),
                        ),
                      ),
                      const Spacer(),
                      if (_activeFilters.isNotEmpty) ...[
                        TextButton(
                          onPressed: () {
                            setSheetState(() => _activeFilters.clear());
                            setState(() {});
                          },
                          child: const Text(
                            'Сбросить',
                            style: TextStyle(color: Color(0xFFE07A5F)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filters.map((f) {
                      final active = _activeFilters.contains(f[0]);
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (active) {
                              _activeFilters.remove(f[0]);
                            } else {
                              _activeFilters.add(f[0]);
                            }
                          });
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            gradient: active ? _greenGradient : null,
                            color: active
                                ? null
                                : AppColors.chipInactiveBg(ctx),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? const Color(0xFF3F8F6B)
                                  : AppColors.border(ctx),
                            ),
                          ),
                          child: Text(
                            f[1],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : AppColors.textPrimary(ctx),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE07A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _activeFilters.isEmpty
                            ? 'Показать все рецепты'
                            : 'Показать (${_filtered.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return ScrollToTopWrapper(
      builder: (controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: '🔍 Поиск рецепта',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary(context),
                      ),
                      filled: true,
                      fillColor: AppColors.fieldBg(context),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFE07A5F),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openFiltersSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: _activeFilters.isNotEmpty
                          ? _greenGradient
                          : null,
                      color: _activeFilters.isEmpty
                          ? AppColors.fieldBg(context)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _activeFilters.isNotEmpty
                            ? const Color(0xFF3F8F6B)
                            : AppColors.border(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 18,
                          color: _activeFilters.isNotEmpty
                              ? Colors.white
                              : const Color(0xFF3F8F6B),
                        ),
                        if (_activeFilters.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${_activeFilters.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openAddRecipe(),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE07A5F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((cat) {
                final active = _category == cat[0];
                return GestureDetector(
                  onTap: () => setState(() => _category = cat[0]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: active ? _accentGradient : null,
                      color: active ? null : AppColors.fieldBg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? const Color(0xFFE07A5F)
                            : AppColors.border(context),
                      ),
                    ),
                    child: Text(
                      cat[1],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: active
                            ? Colors.white
                            : AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _activeFilters.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _activeFilters.map((key) {
                              final label = _filters.firstWhere(
                                (f) => f[0] == key,
                                orElse: () => [key, key],
                              )[1];
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _activeFilters.remove(key)),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    5,
                                    6,
                                    5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: _greenGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _activeFilters.clear()),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'Сбросить',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFE07A5F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _activeFilters.contains('my')
                            ? 'У вас пока нет своих рецептов.\nНажмите «+», чтобы добавить.'
                            : 'Ничего не найдено 🔍\nПопробуйте другой запрос или снимите фильтры',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final r = filtered[i];
                      final key = _recipeKeys.putIfAbsent(
                        r.id,
                        () => GlobalKey(),
                      );
                      return RecipeCard(
                        key: key,
                        recipe: r,
                        initiallyExpanded: r.id == _justOpenedId,
                        onEdit: r.isUserRecipe
                            ? () => _openAddRecipe(existing: r)
                            : null,
                        onDelete: r.isUserRecipe
                            ? () => _deleteUserRecipe(r)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============ ВКЛАДКА «ПРОГРАММЫ» ============
class ProgramsTab extends StatelessWidget {
  final void Function(String recipeId) onOpenRecipe;
  const ProgramsTab({super.key, required this.onOpenRecipe});

  @override
  Widget build(BuildContext context) {
    return ScrollToTopWrapper(
      builder: (controller) => ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: menuPrograms.length,
        itemBuilder: (_, i) =>
            _ProgramCard(program: menuPrograms[i], onOpenRecipe: onOpenRecipe),
      ),
    );
  }
}

class _ProgramCard extends StatefulWidget {
  final MenuProgram program;
  final void Function(String recipeId) onOpenRecipe;
  const _ProgramCard({required this.program, required this.onOpenRecipe});

  @override
  State<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<_ProgramCard> {
  bool _expanded = false;

  Recipe? _findRecipe(String id) {
    try {
      return allRecipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(p.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.slots.length} приёмов · ${p.slots.map((s) => s.recipeId).toSet().length} уникальных блюд',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFE07A5F),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: AppColors.border(context)),
                  const SizedBox(height: 12),
                  Text(
                    p.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...p.slots.map((slot) {
                    final recipe = _findRecipe(slot.recipeId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 4),
                            child: Text(
                              slot.label.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Color(0xFFE07A5F),
                              ),
                            ),
                          ),
                          if (recipe != null) ...[
                            RecipeCard(
                              recipe: recipe,
                              onOpenInList: () =>
                                  widget.onOpenRecipe(recipe.id),
                            ),
                          ] else ...[
                            Text(
                              'Рецепт «${slot.recipeId}» не найден',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                              ),
                            ),
                          ],
                          if (slot.extra != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 6),
                              child: Text(
                                '+ ${slot.extra}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF3F8F6B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============ ВКЛАДКА «ОЗДОРОВЛЕНИЕ» ============
class WellnessTab extends StatelessWidget {
  const WellnessTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ScrollToTopWrapper(
      builder: (controller) => ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: wellnessSections.length,
        itemBuilder: (_, i) => _WellnessCard(section: wellnessSections[i]),
      ),
    );
  }
}

class _WellnessCard extends StatefulWidget {
  final WellnessSection section;
  const _WellnessCard({required this.section});

  @override
  State<_WellnessCard> createState() => _WellnessCardState();
}

class _WellnessCardState extends State<_WellnessCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(s.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF3F8F6B),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: AppColors.border(context)),
                  const SizedBox(height: 12),
                  ...s.blocks.map((b) => _buildBlock(context, b)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, WellnessBlock b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            b.heading,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3F8F6B),
            ),
          ),
          if (b.body != null) ...[
            const SizedBox(height: 6),
            Text(
              b.body!,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
          if (b.bullets != null) ...[
            const SizedBox(height: 6),
            ...b.bullets!.map(
              (x) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(fontSize: 14, color: Color(0xFF3F8F6B)),
                    ),
                    Expanded(
                      child: Text(
                        x,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (b.products != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: b.products!
                  .map(
                    (p) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.isDark(context)
                            ? const Color(0xFF1A3A2A)
                            : const Color(0xFFEAF6F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${p.emoji} ${p.name}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.isDark(context)
                              ? const Color(0xFF8FD4B0)
                              : const Color(0xFF2F6F55),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ============ ВКЛАДКА «МАРАФОН» ============
class MarathonTab extends StatelessWidget {
  const MarathonTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ScrollToTopWrapper(
      builder: (controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          const _MarathonHeader(),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '📋',
            title: 'Чек-лист дня',
            subtitle:
                '${marathonProgram.dailyChecklist.length} пунктов · сбрасывается утром',
            child: _DailyChecklistSection(
              items: marathonProgram.dailyChecklist,
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '📜',
            title: 'Правила марафона',
            subtitle: '${marathonProgram.rules.length} пунктов',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: marathonProgram.rules
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🌅',
            title: 'Завтраки',
            subtitle: '${marathonProgram.breakfasts.length} вариантов',
            child: Column(
              children: marathonProgram.breakfasts
                  .map((m) => _MealOptionTile(option: m))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🥜',
            title: 'Перекусы',
            subtitle: '${marathonProgram.snacks.length} вариантов',
            child: Column(
              children: marathonProgram.snacks
                  .map((m) => _MealOptionTile(option: m))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🍲',
            title: 'Обеды',
            subtitle:
                '${marathonProgram.lunches.length} вариантов · сложные углеводы + белок + овощи',
            child: Column(
              children: marathonProgram.lunches
                  .map((m) => _MealOptionTile(option: m))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🌙',
            title: 'Ужины',
            subtitle: '${marathonProgram.dinners.length} вариантов · до 20:00',
            child: Column(
              children: marathonProgram.dinners
                  .map((m) => _MealOptionTile(option: m))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🌜',
            title: 'Второй ужин',
            subtitle:
                '${marathonProgram.lateSnacks.length} вариантов · до 21:00, только белок',
            child: Column(
              children: marathonProgram.lateSnacks
                  .map((m) => _MealOptionTile(option: m))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🧘',
            title: 'Разгрузочный день',
            subtitle:
                '1 раз в неделю · ${marathonProgram.fastingDay.length} вариантов',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...marathonProgram.fastingDay.map(
                  (m) => _MealOptionTile(option: m),
                ),
                const SizedBox(height: 10),
                Text(
                  'ПРАВИЛА РАЗГРУЗКИ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 6),
                ...marathonProgram.fastingRules.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '• $r',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🛒',
            title: 'Что купить',
            subtitle:
                '${marathonProgram.shoppingList.length} категорий · продуктовая корзина',
            child: _ShoppingListSection(
              categories: marathonProgram.shoppingList,
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '🍽',
            title: 'Правильная тарелка',
            subtitle: 'Схема идеального приёма пищи',
            child: Text(
              marathonProgram.plateAdvice ?? '',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            emoji: '⏰',
            title: 'Что и когда есть',
            subtitle: 'Принципы по приёмам пищи',
            child: Text(
              marathonProgram.timingAdvice ?? '',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ ШАПКА МАРАФОНА ============
class _MarathonHeader extends StatelessWidget {
  const _MarathonHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: _accentGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            marathonProgram.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            marathonProgram.description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ КАРТОЧКА СЕКЦИИ ============
class _SectionCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFE07A5F),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, color: AppColors.border(context)),
                        const SizedBox(height: 10),
                        widget.child,
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ============ КАРТОЧКА ВАРИАНТА ПРИЁМА ============
class _MealOptionTile extends StatefulWidget {
  final MealOption option;
  const _MealOptionTile({required this.option});

  @override
  State<_MealOptionTile> createState() => _MealOptionTileState();
}

class _MealOptionTileState extends State<_MealOptionTile> {
  bool _expanded = false;

  Future<void> _addToDiary() async {
    final o = widget.option;
    final added = await showAddToDiarySheet(
      context: context,
      title: o.title,
      kcal100: o.kcal100.toDouble(),
      protein100: o.protein100.toDouble(),
      fat100: o.fat100.toDouble(),
      carb100: o.carb100.toDouble(),
    );
    if (added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавлено в дневник'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.option;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.isDark(context)
            ? const Color(0xFF252525)
            : const Color(0xFFFAF7F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        if (o.composition != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            o.composition!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '🔥 ${o.kcal100} ккал/100г · Б ${o.protein100} · Ж ${o.fat100} · У ${o.carb100}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _addToDiary,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: Color(0xFF3F8F6B),
                    ),
                    tooltip: 'Добавить в дневник',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFE07A5F),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, color: AppColors.border(context)),
                        const SizedBox(height: 10),
                        if (o.ingredients.isNotEmpty) ...[
                          Text(
                            'СОСТАВ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...o.ingredients.map(
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• $i',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (o.isRecipe) ...[
                          Text(
                            'ПРИГОТОВЛЕНИЕ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...List.generate(
                            o.steps.length,
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE07A5F),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      o.steps[i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (o.note != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.isDark(context)
                                  ? const Color(0xFF1A3A2A)
                                  : const Color(0xFFEAF6F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '💡 ',
                                  style: TextStyle(fontSize: 13),
                                ),
                                Expanded(
                                  child: Text(
                                    o.note!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: AppColors.isDark(context)
                                          ? const Color(0xFF8FD4B0)
                                          : const Color(0xFF2F6F55),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (o.servings > 1) ...[
                          const SizedBox(height: 8),
                          Text(
                            '🍽 Рецепт на ${o.servings} порции',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ============ ЧЕК-ЛИСТ ДНЯ ============
class _DailyChecklistSection extends StatefulWidget {
  final List<List<String>> items;
  const _DailyChecklistSection({required this.items});

  @override
  State<_DailyChecklistSection> createState() => _DailyChecklistSectionState();
}

class _DailyChecklistSectionState extends State<_DailyChecklistSection> {
  static const _storageKey = 'daily_marathon';
  Set<String> _checked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ChecklistStorage.loadDaily(_storageKey);
    if (mounted) {
      setState(() {
        _checked = data;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String id) async {
    setState(() {
      if (_checked.contains(id)) {
        _checked.remove(id);
      } else {
        _checked.add(id);
      }
    });
    await ChecklistStorage.saveDaily(_storageKey, _checked);
  }

  Future<void> _reset() async {
    setState(() => _checked.clear());
    await ChecklistStorage.clearDaily(_storageKey);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final total = widget.items.length;
    final done = _checked.length;
    final allDone = done == total && total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              allDone ? '✅ Всё выполнено!' : 'Выполнено $done из $total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: allDone
                    ? const Color(0xFF3F8F6B)
                    : AppColors.textSecondary(context),
              ),
            ),
            const Spacer(),
            if (done > 0) ...[
              TextButton(
                onPressed: _reset,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'Сбросить',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE07A5F)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ...widget.items.map((item) {
          final id = item[0];
          final title = item[1];
          final isChecked = _checked.contains(id);
          return InkWell(
            onTap: () => _toggle(id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: isChecked ? _greenGradient : null,
                      color: isChecked ? null : Colors.transparent,
                      border: Border.all(
                        color: isChecked
                            ? const Color(0xFF3F8F6B)
                            : AppColors.border(context),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isChecked
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: isChecked
                            ? AppColors.textSecondary(context)
                            : AppColors.textPrimary(context),
                        decoration: isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          '⏰ Сбрасывается автоматически каждое утро',
          style: TextStyle(
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ============ ЧЕК-ЛИСТ СПИСКА ПОКУПОК ============
class _ShoppingListSection extends StatefulWidget {
  final List<ShoppingCategory> categories;
  const _ShoppingListSection({required this.categories});

  @override
  State<_ShoppingListSection> createState() => _ShoppingListSectionState();
}

class _ShoppingListSectionState extends State<_ShoppingListSection> {
  static const _storageKey = 'shopping_marathon';
  Set<String> _checked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ChecklistStorage.load(_storageKey);
    if (mounted) {
      setState(() {
        _checked = data;
        _loading = false;
      });
    }
  }

  String _idFor(String catTitle, String item) => '$catTitle::$item';

  Future<void> _toggle(String id) async {
    setState(() {
      if (_checked.contains(id)) {
        _checked.remove(id);
      } else {
        _checked.add(id);
      }
    });
    await ChecklistStorage.save(_storageKey, _checked);
  }

  Future<void> _reset() async {
    setState(() => _checked.clear());
    await ChecklistStorage.clear(_storageKey);
  }

  int get _totalItems =>
      widget.categories.fold<int>(0, (sum, c) => sum + c.items.length);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final total = _totalItems;
    final done = _checked.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Куплено $done из $total',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F8F6B),
              ),
            ),
            const Spacer(),
            if (done > 0) ...[
              TextButton(
                onPressed: _reset,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'Сбросить',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE07A5F)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(widget.categories.length, (catIdx) {
          final cat = widget.categories[catIdx];
          final checkedInCat = cat.items
              .where((i) => _checked.contains(_idFor(cat.title, i)))
              .length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${cat.emoji} ${cat.title}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$checkedInCat/${cat.items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...cat.items.map((item) {
                  final id = _idFor(cat.title, item);
                  final isChecked = _checked.contains(id);
                  return InkWell(
                    onTap: () => _toggle(id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: isChecked ? _greenGradient : null,
                              color: isChecked ? null : Colors.transparent,
                              border: Border.all(
                                color: isChecked
                                    ? const Color(0xFF3F8F6B)
                                    : AppColors.border(context),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: isChecked
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isChecked
                                    ? AppColors.textSecondary(context)
                                    : AppColors.textPrimary(context),
                                decoration: isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textSecondary(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ============ КНОПКА «ВВЕРХ» ============
class ScrollToTopWrapper extends StatefulWidget {
  final Widget Function(ScrollController controller) builder;
  const ScrollToTopWrapper({super.key, required this.builder});

  @override
  State<ScrollToTopWrapper> createState() => _ScrollToTopWrapperState();
}

class _ScrollToTopWrapperState extends State<ScrollToTopWrapper> {
  final _controller = ScrollController();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _controller.hasClients && _controller.offset > 400;
    if (show != _visible) {
      setState(() => _visible = show);
    }
  }

  void _scrollToTop() {
    _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.builder(_controller),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedScale(
            scale: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_visible,
                child: FloatingActionButton.small(
                  heroTag: null,
                  onPressed: _scrollToTop,
                  backgroundColor: const Color(0xFFE07A5F),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.keyboard_arrow_up),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
