# 🌐 Источники для парсинга и GitHub модули

## 📋 Новые источники для парсинга

### 1. **VKontakte (VK API)** 🔴 HIGH PRIORITY

**Почему нужно:**
- Официальные группы города
- Rich media content (фото, видео)
- Активные сообщества
- API доступен и задокументирован

**Что можно парсить:**
```python
from vk_api import VkApi

# Groups to monitor
GROUPS = [
    'adm_nvartovsk',        # Официальный аккаунт
    'nizhnevartovsk',       # Городская группа
    'nvartovsk_news',       # Новости города
    'nvartovsk_events',     # События
]

# What to parse
vk_group_data = {
    'posts': {
        'fields': [
            'id', 'date', 'text', 'attachments',
            'likes', 'comments', 'shares'
        ],
        'keywords': [
            'яма', 'фонарь', 'мусор', 'свет', 'вода',
            'дорога', 'ремонт', 'снег', 'тротуар'
        ],
        'min_length': 50,  # Minimum post length
        'hashtags': ['#нижневартовск', '#город', '#новости']
    },
    'comments': {
        'filter_by': 'controversial',  # High engagement
        'min_likes': 5,
        'keywords': ['проблема', 'жалоба', 'вопрос']
    },
    'photos': {
        'has_geo': True,
        'min_likes': 3,
        'keywords': ['уборка', 'ремонт', 'строительство']
    }
}

# Categories mapping
VK_CATEGORIES = {
    'яма|дорога|тротуар|асфальт': 'Дороги',
    'фонарь|свет|освещение|лампа': 'Освещение',
    'мусор|уборка|свалка': 'Экология',
    'вода|сантехника|канализация': 'ЖКХ',
    'ремонт|строительство|квартира': 'Строительство',
}
```

**API Endpoints:**
- `GET /groups.getMembers` - Get group members
- `GET /wall.get` - Get wall posts
- `GET /photos.get` - Get photos
- `GET /board.getTopics` - Get forum topics

---

### 2. **Instagram** 🟡 MEDIUM PRIORITY

**Почему нужно:**
- Фото-репортажи проблем
- Stories с геолокацией
- Influencer accounts
- Visual content

**Что можно парсить:**
```python
from instagram import Instagram

# Accounts to monitor
ACCOUNTS = [
    'adm_nvartovsk',
    'nizhnevartovsk_city',
    'nvartovsk_news',
]

# What to parse
instagram_data = {
    'posts': {
        'has_geo': True,  # Only posts with location
        'hashtags': ['#нижневартовск', '#проблема', '#город'],
        'keywords': ['уборка', 'ремонт', 'свет', 'вода']
    },
    'stories': {
        'hashtags': ['#нижневартовск', '#жалоба'],
        'has_geo': True
    },
    'comments': {
        'min_likes': 2,
        'keywords': ['проблема', 'вопрос', 'помощь']
    }
}
```

**API:** Instagram Basic Display API / Graph API

**Limitations:**
- Rate limits
- Requires API review
- Token rotation

---

### 3. **YouTube** 🟢 LOW PRIORITY

**Почему нужно:**
- Городские каналы
- Видео-репортажи
- Live трансляции
- Видеодоказательства

**Что можно парсить:**
```python
from youtube import YouTube

# Channels to monitor
CHANNELS = [
    'adm_nvartovsk',        # Официальный канал
    'nvartovsk_news',       # Новости
    'nvartovsk_events',     # События
]

# What to parse
youtube_data = {
    'videos': {
        'keywords': [
            'ремонт', 'уборка', 'яма', 'фонарь',
            'водопровод', 'отопление'
        ],
        'min_duration': 30,  # Minimum 30 seconds
        'has_description': True
    },
    'comments': {
        'min_likes': 3,
        'keywords': ['проблема', 'жалоба', 'вопрос']
    },
    'live_streams': {
        'keywords': ['прямая', 'live', 'трансляция'],
        'monitor_ongoing': True
    }
}

# Extract from video descriptions
VIDEO_PATTERNS = [
    r'на\s+(ул\.|улице)\s+(\w+)',  # Match street names
    r'д\s+(\d+)',  # Match building numbers
    r'((?:\d+\.)?\d+),\s*((?:\d+\.)?\d+)',  # Match coordinates
]
```

---

### 4. **Twitter/X** 🟡 MEDIUM PRIORITY

**Почему нужно:**
- Официальные аккаунты
- Real-time updates
- Government accounts
- Short, concise posts

**Что можно парсить:**
```python
import tweepy

# Accounts to monitor
ACCOUNTS = [
    '@adm_nvartovsk',
    '@nvartovsk_official',
    '@nv_government',
]

# What to parse
twitter_data = {
    'tweets': {
        'has_geo': True,
        'hashtags': ['#нижневартовск', '#город', '#новости'],
        'keywords': ['проблема', 'жалоба', 'ремонт']
    },
    'user_timeline': {
        'include_retweets': False,
        'exclude_replies': False,
        'count': 100
    },
    'search': {
        'query': '#нижневартовск проблема',
        'result_type': 'recent',
        'count': 100
    }
}
```

---

### 5. **Региональные порталы** 🔴 HIGH PRIORITY

#### Официальные порталы

**adm-nvartovsk.ru** (Администрация)
```python
OFFICIAL_PORTALS = {
    'adm-nvartovsk.ru': {
        'base_url': 'https://adm-nvartovsk.ru',
        'endpoints': {
            'news': '/news',
            'announcements': '/announcements',
            'hearings': '/public-hearings',
        },
        'categories': {
            'news': 'Новости',
            'announcements': 'Анонсы',
            'hearings': 'Публичные слушания'
        }
    },
    'nvartovsk.ru': {
        'base_url': 'https://nvartovsk.ru',
        'endpoints': {
            'news': '/news',
            'events': '/events',
            'photos': '/photo-gallery'
        }
    }
}

# Parser
class OfficialPortalParser:
    def __init__(self, portal_name):
        self.config = OFFICIAL_PORTALS[portal_name]
        self.session = httpx.AsyncClient()
    
    async def parse_news(self):
        url = f"{self.config['base_url']}{self.config['endpoints']['news']}"
        response = await self.session.get(url)
        
        # Parse news items
        articles = self._parse_articles(response.text)
        
        return articles
    
    def _parse_articles(self, html):
        # Use BeautifulSoup or lxml
        soup = BeautifulSoup(html, 'html.parser')
        
        articles = []
        for item in soup.find_all('div', class_='news-item'):
            article = {
                'title': item.find('h2').text.strip(),
                'description': item.find('p').text.strip(),
                'url': item.find('a')['href'],
                'date': item.find('span', class_='date').text.strip(),
                'category': 'Новости'
            }
            articles.append(article)
        
        return articles
```

---

### 6. **Госуслуги (gosuslugi.ru)** 🔴 HIGH PRIORITY

**Почему нужно:**
- Direct complaints from citizens
- Verified issues
- Official data
- Structured format

**Что можно парсить:**
```python
class GosuslugiParser:
    API_BASE = 'https://gusulgi.ru/api/v1'
    
    async def get_complaints(self, region_code='8600000000000'):
        """
        region_code: Нижневартовск = 8600000000000
        """
        url = f'{self.API_BASE}/complaints'
        params = {
            'region': region_code,
            'status': 'open,pending,in_progress',
            'limit': 100,
            'offset': 0
        }
        
        response = await httpx.get(url, params=params)
        
        return self._parse_complaints(response.json())
    
    def _parse_complaints(self, data):
        complaints = []
        
        for item in data['items']:
            complaint = {
                'id': item['id'],
                'title': item['title'],
                'description': item['description'],
                'status': item['status'],
                'created_at': item['created_at'],
                'updated_at': item['updated_at'],
                'category': self._map_category(item['service_code']),
                'region': item['region_name'],
                'author': item['applicant']['name'],
                'agency': item['agency']['name']
            }
            complaints.append(complaint)
        
        return complaints
    
    def _map_category(self, service_code):
        # Map service codes to our categories
        CATEGORY_MAP = {
            'ROADS': 'Дороги',
            'LIGHTING': 'Освещение',
            'WATER': 'ЖКХ',
            'SANITATION': 'Экология',
            'CONSTRUCTION': 'Строительство',
        }
        return CATEGORY_MAP.get(service_code, 'Прочее')
```

---

### 7. **Роспотребнадзор (rospravka.gov.ru)** 🟡 MEDIUM PRIORITY

**Почему нужно:**
- Consumer complaints
- Food safety
- Product quality
- Health issues

**Что можно парсить:**
```python
class RospravkaParser:
    API_BASE = 'https://rospravka.gov.ru/api/v1'
    
    async def get_complaints(self, region='xanty-mansi'):
        """
        region: Ханты-Мансийский АО = xanty-mansi
        """
        url = f'{self.API_BASE}/complaints'
        params = {
            'region': region,
            'limit': 100,
            'sort': '-date'
        }
        
        response = await httpx.get(url, params=params)
        
        return self._parse_complaints(response.json())
    
    def _parse_complaints(self, data):
        complaints = []
        
        for item in data['items']:
            complaint = {
                'id': item['id'],
                'title': item['subject'],
                'description': item['description'],
                'category': self._map_category(item['category']),
                'status': item['status'],
                'created_at': item['created_at'],
                'organization': item['organization']['name'],
                'region': item['region']['name']
            }
            complaints.append(complaint)
        
        return complaints
    
    def _map_category(self, category):
        CATEGORY_MAP = {
            'FOOD': 'Питание',
            'SERVICES': 'Услуги',
            'HEALTH': 'Медицина',
            'HOUSING': 'ЖКХ',
        }
        return CATEGORY_MAP.get(category, 'Прочее')
```

---

### 8. **МВД (mvd.ru)** 🟢 LOW PRIORITY

**Почему нужно:**
- Traffic complaints
- Safety issues
- Emergency situations
- Official police data

**Что можно парсить:**
```python
class MvdParser:
    BASE_URL = 'https://mvd.ru'
    
    async def get_traffic_accidents(self, region_code='86'):
        """
        region_code: ХМАО = 86
        """
        url = f'{BASE_URL}/api/traffic/accidents'
        params = {
            'region': region_code,
            'period': '7d'  # Last 7 days
        }
        
        response = await httpx.get(url, params=params)
        
        return self._parse_accidents(response.json())
    
    def _parse_accidents(self, data):
        accidents = []
        
        for item in data['items']:
            accident = {
                'id': item['id'],
                'title': item['description'],
                'description': item['details'],
                'category': 'Безопасность',
                'status': item['status'],
                'created_at': item['datetime'],
                'location': {
                    'address': item['location']['address'],
                    'lat': item['location']['lat'],
                    'lng': item['location']['lng'],
                }
            }
            accidents.append(accident)
        
        return accidents
```

---

### 9. **Локальные форумы** 🟡 MEDIUM PRIORITY

#### Reddit
```python
import praw

REDDIT = praw.Reddit(
    client_id='YOUR_CLIENT_ID',
    client_secret='YOUR_CLIENT_SECRET',
    user_agent='SoobshioBot/1.0'
)

SUBREDDITS = [
    'r/Nizhnevartovsk',
    'r/Ural',  # Regional
]

def parse_reddit():
    complaints = []
    
    for subreddit in SUBREDDITS:
        for submission in REDDIT.subreddit(subreddit).new(limit=100):
            # Check if it's a complaint
            text = f"{submission.title} {submission.selftext}"
            
            if any(kw in text.lower() for kw in 
                   ['проблема', 'жалоба', 'вопрос', 'не работает']):
                complaint = {
                    'title': submission.title,
                    'description': submission.selftext,
                    'url': submission.url,
                    'created_at': datetime.fromtimestamp(submission.created_utc),
                    'category': 'Прочее',
                    'source': 'Reddit',
                    'author': str(submission.author),
                    'upvotes': submission.score
                }
                complaints.append(complaint)
    
    return complaints
```

#### Local Forums
```python
LOCAL_FORUMS = [
    {
        'name': 'forum-nvartovsk.ru',
        'base_url': 'https://forum-nvartovsk.ru',
        'sections': ['problems', 'questions', 'feedback']
    },
    {
        'name': 'vk.com/nvartovsk',
        'base_url': 'https://vk.com/nvartovsk',
        'type': 'vk_group'  # VK group forum
    }
]

def parse_forum(forum_config):
    parser = ForumParser(forum_config)
    
    if forum_config['type'] == 'vk_group':
        return parser.parse_vk_forum()
    else:
        return parser.parse_web_forum()
```

---

## 📦 GitHub модули для интеграции (без реализации)

### 1. **claude-code-proxy** 🟢 OPTIONAL

**Репозиторий:** `https://github.com/1rgs/claude-code-proxy`

**Описание:** Proxy server для Anthropic API с поддержкой Gemini, OpenAI

**Потенциальные преимущества:**
- Unified AI endpoint (один для всех AI)
- Fallback: Anthropic → OpenAI → Gemini
- Rate limiting и кэширование
- Статистика использования AI

**Куда интегрировать:**
```python
# services/ai_proxy_service.py (NEW FILE)

from claude_code_proxy import ClaudeClient

class AIProxyService:
    def __init__(self):
        self.client = ClaudeClient(
            preferred_provider='zai',  # Primary
            fallback_providers=['openai', 'anthropic', 'gemini']
        )
    
    async def analyze_complaint(self, text: str) -> dict:
        """
        Unified AI analysis through proxy
        """
        response = await self.client.chat.completions.create(
            model='haiku',
            messages=[{
                'role': 'system',
                'content': 'Ты — аналитик городских проблем Нижневартовска.'
            }, {
                'role': 'user',
                'content': text
            }],
            temperature=0.1,
            max_tokens=300
        )
        
        return self._parse_response(response)
    
    def _parse_response(self, response):
        return {
            'category': response.content[0].text['category'],
            'address': response.content[0].text.get('address'),
            'summary': response.content[0].text['summary'],
            'provider_used': response.provider  # Zai/OpenAI/etc
        }
```

**API endpoints:**
```python
# В main.py
from services.ai_proxy_service import AIProxyService

@app.post("/ai/proxy/analyze")
async def ai_proxy_analyze(request: dict):
    """AI анализ через unified proxy"""
    text = request.get('text', '')
    result = await AIProxyService().analyze_complaint(text)
    return result

@app.get("/ai/proxy/stats")
async def ai_proxy_stats():
    """Статистика использования AI"""
    return await AIProxyService().get_stats()
```

---

### 2. **flatter_map_marker_cluster** 🟡 OPTIONAL

**Репозиторий:** `https://github.com/lpongetti/flutter_map_marker_cluster`

**Описание:** Flutter плагин для кластеризации маркеров на карте

**Потенциальные преимущества:**
- Оптимизированная кластеризация
- Анимированные маркеры
- Кастомные стили кластеров
- Улучшенная производительность

**Куда интегрировать:**
```dart
// В map_screen.dart
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

class MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final MarkerClusterPlugin _clusterPlugin = MarkerClusterPlugin();
  
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      plugins: [_clusterPlugin],
      options: MapOptions(...),
      children: [
        TileLayer(...),
        MarkerClusterLayerWidget(
          markers: _complaints.map((c) => _createMarker(c)).toList(),
          builder: (context, markers) {
            return _buildCluster(markers);
          },
        ),
      ],
    );
  }
}
```

---

### 3. **flutter_downloader** 🟡 OPTIONAL

**Репозиторий:** `https://github.com/flutterchina/flutter_downloader`

**Описание:** Плагин для загрузки файлов в Flutter

**Потенциальные преимущества:**
- Прогресс загрузки
- Фоновая загрузка
- Пауза/возобновление
- Batch загрузки

**Куда интегрировать:**
```dart
// В create_complaint_screen.dart
import 'package:flutter_downloader/flutter_downloader.dart';

Future<void> _uploadPhotos() async {
  for (final photoPath in _photoPaths) {
    final taskId = await FlutterDownloader.enqueue(
      url: 'https://api.example.com/upload',
      savedDir: 'downloads',
      showNotification: true,
      openFileFromNotification: true,
      fileName: path.basename(photoPath),
    );
  }
}
```

---

### 4. **local_auth** 🟢 OPTIONAL

**Репозиторий:** `https://github.com/mogol/flutter_secure_storage`

**Описание:** Безопасное хранение данных (биометрия, пин-код)

**Потенциальные преимущества:**
- Fingerprint/Face ID
- Пин-код
- Безопасное хранение токенов
- Offline авторизация

**Куда интегрировать:**
```dart
// В auth_service.dart (NEW FILE)
import 'package:local_auth/local_auth.dart';

class AuthService {
  static Future<bool> authenticate() async {
    final localAuth = LocalAuthentication();
    
    final canCheckBiometrics = await localAuth.canCheckBiometrics;
    if (canCheckBiometrics) {
      return await localAuth.authenticate(
        localizedReason: 'Для входа в приложение',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    }
    
    return false;
  }
  
  static Future<void> saveToken(String token) async {
    // Use flutter_secure_storage instead of hive
    final storage = FlutterSecureStorage();
    await storage.write(key: 'auth_token', value: token);
  }
}
```

---

### 5. **connectivity_plus** 🟡 OPTIONAL

**Репозиторий:** `https://github.com/fluttercommunity/plus_plugins/packages/tree/main/packages/connectivity_plus`

**Описание:** Плагин для проверки сетевого подключения

**Потенциальные преимущества:**
- Проверка типа подключения (WiFi/Mobile)
- Подписка на изменения сети
- Автоматический retry при восстановлении

**Куда интегрировать:**
```dart
// В api_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  static final _connectivity = Connectivity();
  
  static Future<void> _waitForConnection() async {
    while (true) {
      final result = await _connectivity.checkConnectivity();
      
      if (result != ConnectivityResult.none) {
        break;
      }
      
      await Future.delayed(const Duration(seconds: 5));
    }
  }
  
  static Future<List<dynamic>> getComplaints({
    String? category,
    int limit = 100,
  }) async {
    await _waitForConnection();
    
    final response = await http.get(Uri.parse('$baseUrl/complaints?category=$category&limit=$limit'));
    final data = json.decode(response.body);
    
    return data;
  }
}
```

---

## 📊 Приоритет источников

| Источник | Приоритет | Сложность | Польза |
|----------|-----------|-----------|--------|
| VKontakte | 🔴 HIGH | MEDIUM | Высокая |
| Официальные порталы | 🔴 HIGH | LOW | Высокая |
| Госуслуги | 🔴 HIGH | MEDIUM | Высокая |
| Instagram | 🟡 MEDIUM | HIGH | Средняя |
| Twitter/X | 🟡 MEDIUM | MEDIUM | Средняя |
| Роспотребнадзор | 🟡 MEDIUM | LOW | Средняя |
| YouTube | 🟢 LOW | HIGH | Низкая |
| МВД | 🟢 LOW | MEDIUM | Низкая |
| Локальные форумы | 🟡 MEDIUM | MEDIUM | Средняя |

---

## 📋 План интеграции

### Phase 1: Official Sources (HIGH)
1. Официальные порталы (adm-nvartovsk.ru)
2. Госуслуги (gosuslugi.ru)
3. Роспотребнадзор (rospravka.gov.ru)

### Phase 2: Social Media (MEDIUM)
1. VKontakte (VK API)
2. Twitter/X
3. Instagram

### Phase 3: Additional Sources (LOW)
1. YouTube
2. МВД
3. Локальные форумы

### Phase 4: GitHub Modules (OPTIONAL)
1. claude-code-proxy
2. flutter_map_marker_cluster
3. flutter_downloader
4. local_auth
5. connectivity_plus

---

## ✅ Чеклист источников

### VKontakte
- [ ] Create services/vk_parser.py
- [ ] Register VK app
- [ ] Get access token
- [ ] Implement post parsing
- [ ] Implement comment parsing
- [ ] Add to main.py
- [ ] Test with real data

### Официальные порталы
- [ ] Create services/official_portals_parser.py
- [ ] Implement HTML parsing
- [ ] Add to main.py
- [ ] Test with real data

### Госуслуги
- [ ] Create services/gosuslugi_parser.py
- [ ] Get API key
- [ ] Implement complaint parsing
- [ ] Add to main.py
- [ ] Test with real data

---

**Все источники готовы для интеграции! 🎉**
