# 🎯 План консолидации проекта

## 📊 Текущая структура - проблемы

### ❌ Множественные точки входа (4 файла)

| Файл | Описание | Проблема |
|------|----------|----------|
| `main.py` | Основной FastAPI API | ✅ Основной |
| `run_backend.py` | Wrapper для запуска | ⚠️ Лишний |
| `app.py` | Minimal FastAPI stub | ⚠️ Дублирует |
| `serve_web.py` | HTTP сервер для web | ⚠️ Устаревший |

---

## 🗑️ Файлы для удаления

### Критические (удалить немедленно)

1. ✅ `app.py` - дублирует `main.py`
2. ✅ `run_backend.py` - лишний wrapper
3. ✅ `serve_web.py` - устаревший HTTP сервер

### Временные (можно удалить)

4. ⏳ `fix_all.py` - временный скрипт (сохрани в git как archived)

---

## 🔄 Консолидация к одной точке входа

### ✅ Рекомендованный подход

**Единственная точка входа:** `main.py`

**Функционал:**
1. Полный FastAPI API
2. Все endpoints (complaints, clusters, stats, AI analyze)
3. CORS middleware
4. Zai GLM-4.7 integration
5. Nominatim geocoding
6. Telegram parser (можно запустить отдельно)

---

## 📦 Модули из GitHub для интеграции (без реализации)

### 1. claude-code-proxy

**Описание:** Proxy server для Anthropic API с поддержкой Gemini/OpenAI

**Потенциальные преимущества:**
- Unified AI proxy (один endpoint для всех AI)
- Fallback между Anthropic → OpenAI → Gemini
- Rate limiting и кэширование
- Ведение статистики AI запросов

**Куда интегрировать:**
- Создать `services/ai_proxy_service.py`
- Обернуть `zai_service.py` через этот proxy
- Добавить `/ai/proxy` endpoint

**Не интегрировать (согласно запросу):** ✅ Только рекомендации

---

## 🌐 Другие источники для парсинга

### 1. **VKontakte (VK API)**

**Почему:**
- Много городских сообществ
- Rich media (фото, видео)
- API доступен

**Что можно парсить:**
- Посты из групп "Нижневартовск"
- Комментарии
- Фотографии проблем

**API:** `vk.com/dev/API`

---

### 2. **Instagram**

**Почему:**
- Городские аккаунты
- Фото-репортажи
- Stories с гео-локацией

**Что можно парсить:**
- Посты с гео-локацией
- Hashtag #нижневартовск

**API:** `instagram.com/developer`

---

### 3. **YouTube**

**Почему:**
- Городские каналы
- Видео репортажи
- Live трансляции

**Что можно парсить:**
- Видео с проблемами
- Названия видео
- Описания и комментарии

**API:** `youtube.com/api`

---

### 4. **Twitter/X**

**Почему:**
- Города часто используют Twitter
- Реального времени
- API доступен

**Что можно парсить:**
- Tweets с гео-локацией
- Hashtag #нижневартовск
- Мэрия и госструктуры

**API:** `x.com/developer`

---

### 5. **Региональные порталы**

**Почему:**
- Official sources
- News и announcements

**Примеры:**
- `adm-nvartovsk.ru` (официальный)
- `nvartovsk.ru` (региональный)
- `nizhnevartovsk.ru`

**Что можно парсить:**
- News feed
- Official announcements
- Public hearings

---

### 6. **Официальные сервисы**

**Почему:**
- Direct complaints
- Verified problems

**Примеры:**
- `gosuslugi.ru` (Госуслуги)
- `rospravka.gov.ru` (Правки)
- `mvd.ru` (Полиция - только общая информация)

**Что можно парсить:**
- Заявления граждан
- Отклики властей

---

### 7. **Local Forums**

**Почему:**
- Community discussions
- Grassroots complaints

**Примеры:**
- `vk.com/nvartovsk` (форум)
- `forum-nvartovsk.ru`
- `reddit.com/r/Nizhnevartovsk`

**Что можно парсить:**
- Топики
- Комментарии
- Polls

---

## 📱 Flutter экраны - проверка

### ✅ Текущие экраны

| Экран | Файл | Статус |
|-------|------|--------|
| Карта | `map_screen.dart` | ✅ |
| Список жалоб | `complaints_list_screen.dart` | ✅ |
| Создание жалобы | `create_complaint_screen.dart` | ✅ |
| Детали жалобы | `complaint_detail_screen.dart` | ✅ |
| Аналитика | `analytics_screen.dart` | ✅ |

---

### 🔧 Рекомендованные улучшения

#### 1. MapScreen (`lib/lib/screens/map_screen.dart`)

**Текущие проблемы:**
- ⚠️ Нет загрузки состояния (loading state)
- ⚠️ Нет ошибки обработки (error state)
- ⚠️ Нет refresh-to-refresh
- ⚠️ Кластеры не оптимизированы для большого количества
- ⚠️ Нет offline режима (каш не используется)

**Рекомендации:**
```dart
// 1. Добавить loading state
if (_isLoading) {
  return Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

// 2. Добавить error state
if (_error != null) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64),
          Text('Ошибка загрузки: $_error'),
          ElevatedButton(
            onPressed: _loadData,
            child: Text('Повторить'),
          ),
        ],
      ),
    ),
  );
}

// 3. Добавить refresh indicator
RefreshIndicator(
  onRefresh: _loadData,
  child: FlutterMap(...),
)

// 4. Оптимизировать кластеры
final markerCount = _clusters.length;
final useClustering = markerCount > 100; // Threshold

// 5. Добавить offline cache
Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    // 1. Попытаться загрузить из Hive (offline)
    final cachedData = await HiveService.getCachedComplaints();
    if (cachedData != null && cachedData.isNotEmpty) {
      setState(() {
        _complaints = cachedData.map((c) => Complaint.fromJson(c)).toList();
        _isLoading = false;
      });
    }

    // 2. Загрузить из API
    final data = await ApiService.getComplaints();

    // 3. Кэшировать
    await HiveService.cacheComplaints(data);

    setState(() {
      _complaints = data.map((c) => Complaint.fromJson(c)).toList();
      _isLoading = false;
    });
  } catch (e) {
    // Если ошибка API, использовать кэш
    if (cachedData != null) {
      setState(() {
        _complaints = cachedData.map((c) => Complaint.fromJson(c)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}
```

---

#### 2. CreateComplaintScreen (`lib/lib/screens/create_complaint_screen.dart`)

**Текущие проблемы:**
- ⚠️ Нет валидации формы
- ⚠️ Нет сохранения черновика
- ⚠️ Нет фото upload preview
- ⚠️ Нет voice input интеграции
- ⚠️ Нет location permission handling

**Рекомендации:**
```dart
// 1. Добавить валидацию формы
class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isValid() {
    return _titleController.text.trim().isNotEmpty &&
           _descriptionController.text.trim().isNotEmpty &&
           _selectedLocation != null &&
           _selectedCategory != null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _titleController,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Заголовок обязателен';
          }
          if (value.length < 5) {
            return 'Минимум 5 символов';
          }
          return null;
        },
      ),
    );
  }
}

// 2. Добавить сохранение черновика
Timer? _saveTimer;

void _scheduleSave() {
  _saveTimer?.cancel();
  _saveTimer = Timer(const Duration(seconds: 2), () {
    _saveDraft();
  });
}

Future<void> _saveDraft() async {
  final draft = {
    'title': _titleController.text,
    'description': _descriptionController.text,
    'category': _selectedCategory,
    'location': _selectedLocation,
    'createdAt': DateTime.now().toIso8601String(),
  };

  await HiveService.saveDraft(draft);
}

@override
void dispose() {
  _saveTimer?.cancel();
  _titleController.dispose();
  _descriptionController.dispose();
  _addressController.dispose();
  super.dispose();
}

// 3. Добавить фото upload preview
List<File> _photos = [];
List<String> _photoPreviews = [];

Future<void> _pickPhotos() async {
  final picker = ImagePicker();
  final images = await picker.pickMultiImage();

  if (images != null) {
    setState(() {
      _photos = images.map((e) => File(e.path)).toList();
      _photoPreviews = images.map((e) => e.path).toList();
    });
  }
}

// 4. Добавить voice input
Future<void> _startVoiceInput() async {
  try {
    final result = await VoiceService.startListening();

    if (result != null) {
      _descriptionController.text = result;
      _scheduleSave();
    }
  } catch (e) {
    debugPrint('Voice input error: $e');
  }
}

// 5. Добавить location permission
Future<void> _requestLocationPermission() async {
  final status = await Permission.location.request();

  if (status.isGranted) {
    final position = await LocationService.getCurrentPosition();
    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
    });
  } else {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Разрешение'),
        content: Text('Нужна геолокация для определения места'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: Text('Настройки'),
          ),
        ],
      ),
    );
  }
}
```

---

#### 3. ComplaintsListScreen (`lib/lib/screens/complaints_list_screen.dart`)

**Текущие проблемы:**
- ⚠️ Нет infinite scrolling
- ⚠️ Нет pull-to-refresh
- ⚠️ Нет offline режима
- ⚠️ Нет search debouncing

**Рекомендации:**
```dart
// 1. Добавить infinite scrolling
ScrollController _scrollController = ScrollController();
int _currentPage = 1;
bool _hasMore = true;
bool _isLoadingMore = false;

@override
void initState() {
  super.initState();
  _scrollController.addListener(_onScroll);
}

void _onScroll() {
  if (_scrollController.position.pixels ==
      _scrollController.position.maxScrollExtent) {
    _loadMore();
  }
}

Future<void> _loadMore() async {
  if (_isLoadingMore || !_hasMore) return;

  setState(() {
    _isLoadingMore = true;
  });

  try {
    final moreData = await ApiService.getComplaints(
      page: _currentPage + 1,
      limit: 20,
    );

    setState(() {
      _complaints.addAll(moreData);
      _currentPage++;
      _hasMore = moreData.length == 20;
      _isLoadingMore = false;
    });
  } catch (e) {
    setState(() {
      _isLoadingMore = false;
    });
  }
}

// 2. Добавить pull-to-refresh
RefreshIndicator(
  onRefresh: _loadData,
  child: ListView.builder(...),
)

// 3. Добавить search debouncing
Timer? _debounceTimer;

void _onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    _search(query);
  });
}

Future<void> _search(String query) async {
  try {
    final results = await ApiService.searchComplaints(query);
    setState(() {
      _complaints = results;
    });
  } catch (e) {
    debugPrint('Search error: $e');
  }
}
```

---

## 📋 План действий

### 1. Консолидация точек входа (HIGH PRIORITY)

```bash
# 1. Удалить лишние файлы
rm app.py
rm run_backend.py
rm serve_web.py

# 2. Переместить fix_all.py в archived/
mkdir archived
mv fix_all.py archived/

# 3. Обновить README
# Указать main.py как единственную точку входа
```

### 2. Flutter улучшения (MEDIUM PRIORITY)

| Экран | Приоритет | Улучшения |
|-------|-----------|-----------|
| MapScreen | HIGH | Loading, error, refresh, offline, кластеры |
| CreateComplaintScreen | MEDIUM | Валидация, черновики, фото, voice, permissions |
| ComplaintsListScreen | HIGH | Infinite scroll, pull-to-refresh, offline, search debounce |

### 3. Новые источники парсинга (LOW PRIORITY)

| Источник | Приоритет | Сложность |
|----------|-----------|-----------|
| VKontakte | HIGH | MEDIUM |
| Instagram | MEDIUM | HIGH |
| YouTube | LOW | HIGH |
| Twitter/X | MEDIUM | MEDIUM |
| Regional portals | HIGH | LOW |
| Gov services | HIGH | MEDIUM |
| Forums | MEDIUM | LOW |

### 4. AI Proxy интеграция (LOW PRIORITY)

| Модуль | Сложность | Необходимость |
|--------|-----------|---------------|
| claude-code-proxy | MEDIUM | MEDIUM |

---

## ✅ Чеклист

### Консолидация

- [ ] Удалить `app.py`
- [ ] Удалить `run_backend.py`
- [ ] Удалить `serve_web.py`
- [ ] Переместить `fix_all.py` в `archived/`
- [ ] Обновить README с `main.py` как единственной точкой
- [ ] Обновить документацию

### Flutter улучшения

- [ ] MapScreen - Loading state
- [ ] MapScreen - Error handling
- [ ] MapScreen - Pull-to-refresh
- [ ] MapScreen - Offline cache
- [ ] MapScreen - Кластеризация optimization
- [ ] CreateComplaintScreen - Form validation
- [ ] CreateComplaintScreen - Draft save
- [ ] CreateComplaintScreen - Photo preview
- [ ] CreateComplaintScreen - Voice input
- [ ] CreateComplaintScreen - Location permissions
- [ ] ComplaintsListScreen - Infinite scroll
- [ ] ComplaintsListScreen - Pull-to-refresh
- [ ] ComplaintsListScreen - Search debounce

---

## 📚 Документация к созданию

1. `CONSOLIDATION_PLAN.md` - Этот план
2. `FLUTTER_IMPROVEMENTS.md` - Детальные улучшения Flutter
3. `PARSING_SOURCES.md` - Источники для парсинга
4. `GITHUB_INTEGRATION.md` - Модули из GitHub для интеграции
