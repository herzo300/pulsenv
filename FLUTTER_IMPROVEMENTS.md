# 📱 Flutter Screen Improvements - Detailed Analysis

## 🗺️ MapScreen (`lib/lib/screens/map_screen.dart`)

### Current Issues

| Issue | Severity | Description |
|-------|----------|-------------|
| No loading state | HIGH | Shows blank screen while loading |
| No error state | HIGH | No visual feedback on errors |
| No pull-to-refresh | MEDIUM | Can't refresh complaints |
| No offline mode | MEDIUM | No cached data when offline |
| Clusters not optimized | LOW | Performance with 100+ markers |
| No marker clustering | MEDIUM | Individual markers only |

### Recommended Improvements

#### 1. Loading State
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: _isLoading
      ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка жалоб...'),
            ],
          ),
        )
      : _buildMap(),
  );
}
```

#### 2. Error State with Retry
```dart
Widget _buildErrorState() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Ошибка загрузки данных',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(_error ?? 'Неизвестная ошибка'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => HiveService.clearCache().then((_) => _loadData()),
            icon: const Icon(Icons.delete),
            label: const Text('Очистить кэш'),
          ),
        ],
      ),
    ),
  );
}
```

#### 3. Pull-to-Refresh
```dart
@override
Widget build(BuildContext context) {
  return RefreshIndicator(
    onRefresh: _loadData,
    child: _isLoading ? _buildLoadingState() : _buildMap(),
  );
}
```

#### 4. Offline Mode with Cache
```dart
Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    // 1. Try loading from cache (Hive)
    final cachedComplaints = await HiveService.getCachedComplaints();
    if (cachedComplaints != null && cachedComplaints.isNotEmpty) {
      setState(() {
        _complaints = cachedComplaints;
        _isLoading = false;
      });
    }

    // 2. Load fresh data from API
    final results = await Future.wait([
      ApiService.getComplaints(category: _selectedCategory, limit: 500),
      ApiService.getClusters(),
    ]);

    final complaintsData = results[0] as List<Map<String, dynamic>>;
    final clustersData = results[1] as List<Map<String, dynamic>>;

    // 3. Cache the fresh data
    await HiveService.cacheComplaints(complaintsData);

    setState(() {
      _complaints = complaintsData.map((c) => Complaint.fromJson(c)).toList();
      _clusters = clustersData;
      _isLoading = false;
      _isOffline = false;
    });
  } on SocketException catch (e) {
    // Network error - use cached data
    setState(() {
      _isLoading = false;
      _isOffline = true;
    });
    debugPrint('Network error (using cache): $e');
  } catch (e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
    debugPrint('Error loading data: $e');
  }
}

// Show offline indicator
Widget _buildOfflineIndicator() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    height: _isOffline ? 56 : 0,
    color: Colors.orange.shade100,
    child: _isOffline
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.cloud_off, color: Colors.orange),
                SizedBox(width: 12),
                Text('Офлайн режим. Данные из кэша.'),
                Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
          )
        : const SizedBox.shrink(),
  );
}
```

#### 5. Optimized Clustering
```dart
Widget _buildMap() {
  final useClustering = _complaints.length > 100;

  if (!useClustering) {
    // Show individual markers
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentCenter,
        initialZoom: _currentZoom,
        minZoom: 10,
        maxZoom: 18,
        onTap: (tapPosition, point) {
          // Check if tapped on a complaint
          for (final complaint in _complaints) {
            final complaintLocation = LatLng(complaint.lat, complaint.lng);
            final distance = Distance().as(
              LengthUnit.Kilometers,
              point,
              complaintLocation,
            );
            if (distance < 0.1) { // 100m radius
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ComplaintDetailScreen(complaint: complaint),
                ),
              );
              return;
            }
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgent: 'SoobshioApp/1.0',
        ),
        MarkerLayer(
          markers: _complaints
              .map((c) => _createMarker(c))
              .toList(),
        ),
      ],
    );
  }

  // Show clusters
  return FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      initialCenter: _currentCenter,
      initialZoom: _currentZoom,
      minZoom: 10,
      maxZoom: 18,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgent: 'SoobshioApp/1.0',
      ),
      MarkerLayer(
        markers: _clusters
            .map((c) => Marker(
                  width: 40,
                  height: 40,
                  point: LatLng(c['center_lat'], c['center_lon']),
                  builder: (ctx) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.3),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Center(
                      child: Text(
                        c['complaints_count'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    ],
  );
}
```

#### 6. Category Filter with Chips
```dart
Widget _buildCategoryChips() {
  return Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = _selectedCategory == category['name'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(category['name']),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedCategory = selected ? category['name'] : null;
              });
              _loadData();
            },
            avatar: category['icon'] != null
                ? Text(category['icon'])
                : null,
            backgroundColor: isSelected
                ? Colors.blue.withOpacity(0.2)
                : Colors.grey.shade100,
          ),
        );
      },
    ),
  );
}
```

---

## ✍️ CreateComplaintScreen (`lib/lib/screens/create_complaint_screen.dart`)

### Current Issues

| Issue | Severity | Description |
|-------|----------|-------------|
| No form validation | HIGH | Can submit empty form |
| No draft save | MEDIUM | Lost progress on app close |
| No photo preview | MEDIUM | Can't see selected photos |
| No voice input | LOW | No voice dictation |
| No location permission handling | MEDIUM | Crashes without permission |
| No auto-save | MEDIUM | Lost progress on screen close |
| No offline mode | LOW | Can't create offline |

### Recommended Improvements

#### 1. Form Validation
```dart
class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isValid() {
    return _titleController.text.trim().length >= 5 &&
           _descriptionController.text.trim().length >= 10 &&
           _selectedLocation != null &&
           _selectedCategory != null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Заголовок *',
              hintText: 'Опишите проблему (минимум 5 символов)',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Заголовок обязателен';
              }
              if (value.trim().length < 5) {
                return 'Минимум 5 символов';
              }
              if (value.trim().length > 200) {
                return 'Максимум 200 символов';
              }
              return null;
            },
            onChanged: (_) => _scheduleDraftSave(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Описание *',
              hintText: 'Подробно опишите проблему (минимум 10 символов)',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Описание обязательно';
              }
              if (value.trim().length < 10) {
                return 'Минимум 10 символов';
              }
              if (value.trim().length > 2000) {
                return 'Максимум 2000 символов';
              }
              return null;
            },
            onChanged: (_) => _scheduleDraftSave(),
          ),
        ],
      ),
    );
  }
}
```

#### 2. Draft Auto-Save
```dart
Timer? _saveTimer;

void _scheduleDraftSave() {
  _saveTimer?.cancel();
  _saveTimer = Timer(const Duration(seconds: 2), () {
    _saveDraft();
  });
}

Future<void> _saveDraft() async {
  if (!_isValid()) return;

  final draft = {
    'title': _titleController.text.trim(),
    'description': _descriptionController.text.trim(),
    'address': _addressController.text.trim(),
    'category': _selectedCategory,
    'location': {
      'lat': _selectedLocation?.latitude,
      'lng': _selectedLocation?.longitude,
    },
    'photos': _photoPaths,
    'createdAt': DateTime.now().toIso8601String(),
  };

  try {
    await HiveService.saveDraft('create_complaint', draft);
    debugPrint('Draft saved');
  } catch (e) {
    debugPrint('Error saving draft: $e');
  }
}

Future<void> _loadDraft() async {
  try {
    final draft = await HiveService.getDraft('create_complaint');
    if (draft != null) {
      setState(() {
        _titleController.text = draft['title'] ?? '';
        _descriptionController.text = draft['description'] ?? '';
        _addressController.text = draft['address'] ?? '';
        _selectedCategory = draft['category'];
        if (draft['location'] != null) {
          _selectedLocation = LatLng(
            draft['location']['lat']?.toDouble() ?? 0,
            draft['location']['lng']?.toDouble() ?? 0,
          );
        }
        if (draft['photos'] != null) {
          _photoPaths = List<String>.from(draft['photos']);
          _photoControllers = _photoPaths
              .map((p) => TextEditingController(text: p))
              .toList();
        }
      });
    }
  } catch (e) {
    debugPrint('Error loading draft: $e');
  }
}

void _clearDraft() async {
  await HiveService.deleteDraft('create_complaint');
}

@override
void initState() {
  super.initState();
  _loadDraft();
  _loadCategories();
}

@override
void dispose() {
  _saveTimer?.cancel();
  _titleController.dispose();
  _descriptionController.dispose();
  _addressController.dispose();
  for (final controller in _photoControllers) {
    controller.dispose();
  }
  super.dispose();
}
```

#### 3. Photo Upload with Preview
```dart
List<File> _photos = [];
List<String> _photoPaths = [];
List<TextEditingController> _photoControllers = [];

Future<void> _pickPhotos() async {
  final ImagePicker picker = ImagePicker();
  final List<XFile>? images = await picker.pickMultiImage(
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );

  if (images != null && images.isNotEmpty) {
    setState(() {
      _photos.addAll(images.map((e) => File(e.path)));
      _photoPaths.addAll(images.map((e) => e.path));
      _photoControllers.addAll(
          List.generate(images.length, (_) => TextEditingController()));
    });
    _scheduleDraftSave();
  }
}

Widget _buildPhotoPreviews() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Фотографии', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ..._photoPaths.asMap().entries.map((entry) {
            final index = entry.key;
            final path = entry.value;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _photos.removeAt(index);
                        _photoPaths.removeAt(index);
                        _photoControllers.removeAt(index);
                      });
                      _scheduleDraftSave();
                    },
                  ),
                ),
              ],
            );
          }),
          GestureDetector(
            onTap: _pickPhotos,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_a_photo, size: 32),
            ),
          ),
        ],
      ),
    ],
  );
}
```

#### 4. Voice Input Integration
```dart
Future<void> _startVoiceInput() async {
  if (_isListening) {
    await VoiceService.stopListening();
    setState(() {
      _isListening = false;
    });
    return;
  }

  setState(() {
    _isListening = true;
  });

  try {
    final result = await VoiceService.startListening(
      locale: 'ru_RU',
      partialResults: true,
      onResult: (text) {
        _descriptionController.text = text;
        _scheduleDraftSave();
      },
    );

    if (result != null && result.isNotEmpty) {
      _descriptionController.text = result;
      _scheduleDraftSave();
    }
  } on PlatformException catch (e) {
    debugPrint('Voice input error: $e');
    _showError('Голосовой ввод недоступен. Используйте клавиатуру.');
  } finally {
    setState(() {
      _isListening = false;
    });
  }
}

Widget _buildVoiceInputButton() {
  return VoiceInputWidget(
    isListening: _isListening,
    onStart: _startVoiceInput,
    onStop: () async {
      await VoiceService.stopListening();
      setState(() {
        _isListening = false;
      });
    },
  );
}
```

#### 5. Location Permission Handling
```dart
Future<void> _requestLocationPermission() async {
  final status = await Permission.location.request();

  if (status.isGranted) {
    await _loadCurrentLocation();
  } else if (status.isPermanentlyDenied) {
    _showPermissionDialog(
      title: 'Доступ к геолокации',
      content: 'Для автоматического определения местоположения требуется доступ к геолокации. Пожалуйста, разрешите доступ в настройках.',
      onOpenSettings: () => openAppSettings(),
    );
  } else {
    _showError('Доступ к геолокации отклонён');
  }
}

Future<void> _loadCurrentLocation() async {
  try {
    final position = await LocationService.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _addressController.text = 'Загрузка адреса...';
    });

    // Reverse geocode
    final address = await ApiService.reverseGeocode(
      lat: position.latitude,
      lng: position.longitude,
    );

    setState(() {
      _addressController.text = address ?? 'Невозможно определить адрес';
    });
    _scheduleDraftSave();
  } on LocationServiceDisabledException {
    _showError('Геолокация отключена. Включите её в настройках.');
  } on LocationPermissionDeniedException {
    _showError('Доступ к геолокации отклонён.');
  } catch (e) {
    debugPrint('Error loading location: $e');
    _showError('Ошибка определения местоположения');
  }
}

void _showPermissionDialog({
  required String title,
  required String content,
  required VoidCallback onOpenSettings,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onOpenSettings();
          },
          child: const Text('Настройки'),
        ),
      ],
    ),
  );
}
```

#### 6. Submit with Loading and Offline Queue
```dart
Future<void> _submitComplaint() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final complaint = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'address': _addressController.text.trim(),
      'category': _selectedCategory,
      'latitude': _selectedLocation?.latitude,
      'longitude': _selectedLocation?.longitude,
      'photos': _photoPaths,
      'source': 'mobile_app',
    };

    final result = await ApiService.createComplaint(complaint);

    // Clear draft on success
    await _clearDraft();

    if (mounted) {
      Navigator.pop(context, result);
    }
  } on SocketException catch (e) {
    // Offline - queue for later
    await HiveService.queueComplaint(complaint);
    _showSuccess('Жалоба сохранена и будет отправлена при подключении к интернету');
    if (mounted) {
      Navigator.pop(context);
    }
  } catch (e) {
    _showError('Ошибка отправки жалобы: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
```

---

## 📋 ComplaintsListScreen (`lib/lib/screens/complaints_list_screen.dart`)

### Current Issues

| Issue | Severity | Description |
|-------|----------|-------------|
| No infinite scrolling | HIGH | Loads all at once, can be slow |
| No pull-to-refresh | MEDIUM | Can't refresh list |
| No offline mode | MEDIUM | Shows blank when offline |
| No search debouncing | LOW | Makes API calls on every keystroke |
| No filtering | MEDIUM | Can't filter by category/status |

### Recommended Improvements

#### 1. Infinite Scrolling
```dart
ScrollController _scrollController = ScrollController();
int _currentPage = 1;
int _pageSize = 20;
bool _hasMore = true;
bool _isLoadingMore = false;

@override
void initState() {
  super.initState();
  _scrollController.addListener(_onScroll);
  _loadData();
}

void _onScroll() {
  if (_scrollController.position.pixels >=
      _scrollController.position.maxScrollExtent - 200) {
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
      limit: _pageSize,
      category: _selectedCategory,
    );

    setState(() {
      _complaints.addAll(moreData);
      _currentPage++;
      _hasMore = moreData.length == _pageSize;
      _isLoadingMore = false;
    });
  } catch (e) {
    debugPrint('Error loading more: $e');
    setState(() {
      _isLoadingMore = false;
    });
  }
}

@override
void dispose() {
  _scrollController.dispose();
  super.dispose();
}
```

#### 2. Pull-to-Refresh
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: _buildComplaintsList(),
    ),
  );
}

Future<void> _refresh() async {
  _currentPage = 1;
  _hasMore = true;
  _complaints.clear();
  await _loadData();
}
```

#### 3. Offline Mode with Cache
```dart
Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    // 1. Load from cache
    final cachedComplaints = await HiveService.getCachedComplaints();
    if (cachedComplaints != null && cachedComplaints.isNotEmpty) {
      setState(() {
        _complaints = cachedComplaints;
        _isLoading = false;
      });
    }

    // 2. Load fresh data
    final freshData = await ApiService.getComplaints(
      page: _currentPage,
      limit: _pageSize,
      category: _selectedCategory,
    );

    // 3. Update cache
    if (_currentPage == 1) {
      await HiveService.cacheComplaints(freshData);
    }

    setState(() {
      _complaints = freshData;
      _isLoading = false;
      _isOffline = false;
    });
  } on SocketException catch (e) {
    // Network error - use cached data
    setState(() {
      _isLoading = false;
      _isOffline = true;
    });
    debugPrint('Network error (using cache): $e');
  } catch (e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}
```

#### 4. Search Debouncing
```dart
Timer? _debounceTimer;

void _onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    _search(query);
  });
}

Future<void> _search(String query) async {
  if (query.isEmpty) {
    _refresh();
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final results = await ApiService.searchComplaints(
      query: query,
      category: _selectedCategory,
    );

    setState(() {
      _complaints = results;
      _isLoading = false;
      _hasMore = false; // No pagination for search
    });
  } catch (e) {
    debugPrint('Search error: $e');
    setState(() {
      _isLoading = false;
    });
  }
}

@override
void dispose() {
  _debounceTimer?.cancel();
  super.dispose();
}
```

#### 5. Filter Chips
```dart
Widget _buildFilters() {
  return Column(
    children: [
      Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category['name'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category['name']),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = selected ? category['name'] : null;
                  });
                  _refresh();
                },
              ),
            );
          },
        ),
      ),
      if (_selectedCategory != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Chip(
            label: Text(_selectedCategory!),
            deleteIcon: const Icon(Icons.close),
            onDeleted: () {
              setState(() {
                _selectedCategory = null;
              });
              _refresh();
            },
          ),
        ),
    ],
  );
}
```

---

## 📊 AnalyticsScreen

### Current Issues

| Issue | Severity | Description |
|-------|----------|-------------|
| No data refresh | MEDIUM | Shows stale data |
| No export | LOW | Can't export analytics |
| No date range | LOW | Can't filter by date |

### Recommended Improvements

```dart
// Add pull-to-refresh and export button
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Аналитика'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Обновить',
        ),
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _exportAnalytics,
          tooltip: 'Экспорт',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _loadData,
      child: _buildCharts(),
    ),
  );
}

Future<void> _exportAnalytics() async {
  try {
    final csv = _generateCSV();
    await _shareFile(csv, 'analytics.csv');
  } catch (e) {
    _showError('Ошибка экспорта: $e');
  }
}

String _generateCSV() {
  final buffer = StringBuffer();
  buffer.writeln('Категория,Количество,Среднее время решения');
  
  for (final data in _categoryData) {
    buffer.writeln('${data['category']},${data['count']},${data['avgTime']}');
  }
  
  return buffer.toString();
}
```

---

## 📦 Summary

### Priority Improvements

| Screen | Priority | Improvements |
|--------|----------|--------------|
| MapScreen | HIGH | Loading, error, refresh, offline, clustering, category filter |
| CreateComplaintScreen | HIGH | Validation, draft save, photo preview, voice input, permissions |
| ComplaintsListScreen | HIGH | Infinite scroll, pull-to-refresh, offline, search debounce, filter |
| AnalyticsScreen | MEDIUM | Refresh, export, date range |

### Files to Update

1. `lib/lib/screens/map_screen.dart`
2. `lib/lib/screens/create_complaint_screen.dart`
3. `lib/lib/screens/complaints_list_screen.dart`
4. `lib/lib/services/hive_service.dart` - Add draft saving and caching
5. `lib/lib/services/voice_service.dart` - Add voice input implementation
6. `lib/lib/services/location_service.dart` - Add permission handling

### Dependencies to Add

```yaml
dependencies:
  # Voice input
  speech_to_text: ^6.6.0
  
  # Location permissions
  geolocator: ^12.0.0
  permission_handler: ^11.3.1
  
  # Image picker
  image_picker: ^1.1.2
  
  # File sharing
  share_plus: ^10.1.2
  
  # Already have
  hive: ^2.2.3
  flutter_map: ^7.0.2
```
