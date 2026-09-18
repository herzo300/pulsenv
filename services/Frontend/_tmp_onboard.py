# -*- coding: utf-8 -*-
p = r'C:\Soobshio_project\services\Frontend\lib\widgets\onboarding_overlay.dart'
s = open(p, encoding='utf-8', newline='').read()

# Светлый фон
old_bg = '''              filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),'''
new_bg = '''              filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: Container(
                color: const Color(0xFF0E2438).withOpacity(0.45),
              ),'''
assert old_bg in s, 'bg not found'
s = s.replace(old_bg, new_bg, 1)

# Карточка: светлая, с фото города сверху
old_card = '''                    child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 340),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1424).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: PulseColors.primary.withOpacity(0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PulseColors.primary.withOpacity(0.12),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated Glowing Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: PulseColors.primary.withOpacity(0.15),
                              border: Border.all(
                                color: PulseColors.primary.withOpacity(0.5),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PulseColors.primary.withOpacity(0.2),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              step.icon,
                              color: PulseColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 18),'''
new_card = '''                    child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 480),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withOpacity(0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withOpacity(0.25),
                            blurRadius: 30,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Реальное фото города (живой кадр с городской камеры)
                          if (step.photo != null)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(27)),
                              child: Image.network(
                                'http://45.153.68.59/${step.photo}',
                                height: 168,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 168,
                                  color: const Color(0xFFE0F2FE),
                                  child: const Icon(Icons.location_city_rounded,
                                      size: 64, color: Color(0xFF0284C7)),
                                ),
                              ),
                            ),
                          Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          // Иконка-бейдж (на светлом фоне)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0EA5E9).withOpacity(0.12),
                              border: Border.all(
                                color: const Color(0xFF0EA5E9).withOpacity(0.6),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withOpacity(0.25),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              step.icon,
                              color: const Color(0xFF0284C7),
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),'''
assert old_card in s, 'card not found'
s = s.replace(old_card, new_card, 1)

# Заголовок
old_t1 = '''                          Text(
                            step.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontFamily: 'Inter',
                              shadows: [
                                Shadow(
                                  color: PulseColors.primary.withOpacity(0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),'''
new_t1 = '''                          Text(
                            step.title,
                            style: const TextStyle(
                              color: Color(0xFF0F2A3F),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                              fontFamily: 'Inter',
                            ),
                          ),'''
assert old_t1 in s, 'title not found'
s = s.replace(old_t1, new_t1, 1)

# Описание
old_t2 = '''                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontFamily: 'Inter',
                              height: 1.45,
                            ),
                          ),'''
new_t2 = '''                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF33566E),
                              fontSize: 13.5,
                              fontFamily: 'Inter',
                              height: 1.5,
                            ),
                          ),'''
assert old_t2 in s, 'desc not found'
s = s.replace(old_t2, new_t2, 1)

open(p, 'w', encoding='utf-8', newline='').write(s)
print('light onboarding card installed')
