(() => {
  const STORY_OVERVIEW = {
    updatedAt: '09.03.2026',
    kpiCards: [
      {
        label: 'Сводных витрин',
        value: '10',
        text: 'Экономика, жители, инфраструктура, среда и история собраны в одном слое без повторяющихся разделов.'
      },
      {
        label: 'Категорий',
        value: '5',
        text: 'Каждый блок закреплен за своей категорией, поэтому навигация не уводит в отдельные страницы и вторичные сценарии.'
      },
      {
        label: 'Обновление',
        value: '42+',
        text: 'Подтянуты сводки по жилью, соцсфере, имуществу и контрактам. Срез актуализирован на 09.03.2026.'
      }
    ]
  };

  const STORY_BLOCKS = [
    {
      id: 'economy-index',
      tab: 'economy',
      title: 'Экономический импульс',
      sub: 'Сводный индекс по бюджету, зарплате и МСП вместо нескольких пересекающихся карточек',
      icon: '◈',
      iconBg: 'rgba(251, 191, 36, 0.14)',
      pill: 'Рост',
      pillColor: '#fbbf24',
      wide: true,
      render: renderEconomyIndex
    },
    {
      id: 'contract-cycle',
      tab: 'economy',
      title: 'Контрактный цикл',
      sub: 'Объем муниципальных договоров и их структура как отдельный управленческий контур',
      icon: '▣',
      iconBg: 'rgba(236, 72, 153, 0.14)',
      pill: 'Контракты',
      pillColor: '#ec4899',
      render: renderContractCycle
    },
    {
      id: 'asset-circuit',
      tab: 'economy',
      title: 'Имущественный контур',
      sub: 'Недвижимость, земля и доходы от аренды сведены в одну обзорную витрину',
      icon: '⌘',
      iconBg: 'rgba(59, 130, 246, 0.14)',
      pill: 'Активы',
      pillColor: '#3b82f6',
      render: renderAssetCircuit
    },
    {
      id: 'people-profile',
      tab: 'people',
      title: 'Поколенческий профиль',
      sub: 'Структура населения, городские роли и смена возрастного баланса',
      icon: '◉',
      iconBg: 'rgba(0, 240, 255, 0.12)',
      pill: 'Жители',
      pillColor: '#00f0ff',
      render: renderPeopleProfile
    },
    {
      id: 'social-core',
      tab: 'people',
      title: 'Социальное ядро',
      sub: 'Школы, детсады, спорт и обеспеченность инфраструктурой в одном компактном блоке',
      icon: '✚',
      iconBg: 'rgba(124, 58, 237, 0.16)',
      pill: 'Соцсфера',
      pillColor: '#a78bfa',
      render: renderSocialCore
    },
    {
      id: 'infra-contour',
      tab: 'infra',
      title: 'Инфраструктурный контур',
      sub: 'Маршруты, качество дорог и плотность городской мобильности',
      icon: '↔',
      iconBg: 'rgba(34, 197, 94, 0.14)',
      pill: 'Среда',
      pillColor: '#22c55e',
      render: renderInfraContour
    },
    {
      id: 'housing-cycle',
      tab: 'infra',
      title: 'Жилищный цикл',
      sub: 'Разрешения, ввод жилья и типология этажности без возврата к старому строительному экрану',
      icon: '▥',
      iconBg: 'rgba(255, 107, 53, 0.14)',
      pill: 'Жилье',
      pillColor: '#ff6b35',
      render: renderHousingCycle
    },
    {
      id: 'city-environment',
      tab: 'city',
      title: 'Городская среда',
      sub: 'Экология, обновление районов и распределение приоритетов развития',
      icon: '△',
      iconBg: 'rgba(124, 58, 237, 0.16)',
      pill: 'Фокус',
      pillColor: '#a78bfa',
      render: renderCityEnvironment
    },
    {
      id: 'signals-feed',
      tab: 'city',
      title: 'Городской сигнал',
      sub: 'Короткая лента наблюдений и приоритетов, которая объясняет текущий фокус развития',
      icon: '✦',
      iconBg: 'rgba(255, 107, 53, 0.14)',
      pill: 'Сейчас',
      pillColor: '#ff6b35',
      render: renderSignalsFeed
    },
    {
      id: 'timeline',
      tab: 'timeline',
      title: 'История города',
      sub: 'Ключевые вехи, которые связывают рост города с текущим цифровым и инфраструктурным контуром',
      icon: '⟡',
      iconBg: 'rgba(0, 240, 255, 0.12)',
      pill: 'Хронология',
      pillColor: '#00f0ff',
      wide: true,
      expanded: true,
      render: renderTimeline
    }
  ];

  const TABS = [
    { id: 'all', label: 'Все' },
    { id: 'economy', label: 'Экономика' },
    { id: 'people', label: 'Люди' },
    { id: 'infra', label: 'Инфраструктура' },
    { id: 'city', label: 'Город' },
    { id: 'timeline', label: 'История' }
  ];

  const CATEGORY_JUMPS = [
    { id: 'economy', label: 'Экономика', meta: 'Индекс, контракты и имущественный контур' },
    { id: 'people', label: 'Люди', meta: 'Демография и социальное ядро' },
    { id: 'infra', label: 'Инфраструктура', meta: 'Дороги, мобильность и жилье' },
    { id: 'city', label: 'Город', meta: 'Среда, экология и текущие сигналы' },
    { id: 'timeline', label: 'История', meta: 'Хронология развития города' }
  ];

  const charts = new Map();

  function renderUnifiedStory() {
    const mountNode = document.getElementById('city-story-merged');
    if (!mountNode) return;

    mountNode.innerHTML = `
      <div class="merged-story-shell">
        <div class="story-header">
          <div class="story-hero">
            <span class="story-kicker">Городской слой данных</span>
            <h2 class="story-title">Город в динамике</h2>
            <p class="story-lead">Единый раздел собирает историю, жителей, среду, жилье, имущественный контур и контрактный цикл в одном экране. Детальные графики из основного дашборда не повторяются: здесь оставлены только самостоятельные сводки и отдельные анимационные сценарии.</p>
          </div>
          <div class="story-header-grid">
            ${STORY_OVERVIEW.kpiCards.map((item) => `
              <div class="story-mini-panel">
                <span class="story-mini-label">${item.label}</span>
                <div class="story-mini-value">${item.value}</div>
                <div class="story-mini-copy">${item.text}</div>
              </div>
            `).join('')}
          </div>
        </div>
        <div class="story-tabs" id="story-tabs">
          ${TABS.map((tab) => `<button class="story-tab${tab.id === 'all' ? ' active' : ''}" type="button" data-story-tab="${tab.id}">${tab.label}</button>`).join('')}
        </div>
        <div class="story-nav-shell">
          <div class="story-nav-copy">
            <div class="story-nav-title">Навигация по категориям</div>
            <div class="story-nav-subtitle">Быстрый переход к нужному контуру без ручного пролистывания секции.</div>
          </div>
          <div class="story-anchor-nav" id="story-anchor-nav">
            ${CATEGORY_JUMPS.map((item) => `
              <a
                href="#story-category-${item.id}"
                class="story-anchor-link${item.id === 'economy' ? ' is-active' : ''}"
                data-story-jump="${item.id}"
              >
                <div class="story-anchor-top">
                  <span class="story-anchor-label">${item.label}</span>
                  <span class="story-anchor-count">${countBlocksForTab(item.id)} блока</span>
                </div>
                <div class="story-anchor-meta">${item.meta}</div>
              </a>
            `).join('')}
          </div>
        </div>
        <div class="story-grid" id="story-grid"></div>
      </div>
    `;

    const grid = mountNode.querySelector('#story-grid');
    const seenTabs = new Set();
    STORY_BLOCKS.forEach((block, index) => {
      const isFirstTabBlock = !seenTabs.has(block.tab);
      seenTabs.add(block.tab);
      grid.appendChild(buildStoryBlock(block, index, isFirstTabBlock));
    });

    bindTabs(mountNode);
    revealVisibleBlocks();
    setActiveTab(mountNode, 'all');
  }

  function buildStoryBlock(block, index, isFirstTabBlock) {
    const article = document.createElement('article');
    article.className = `story-block${block.wide ? ' story-block-wide' : ''}${block.expanded ? ' expanded' : ''}`;
    article.dataset.storyTab = block.tab;
    article.dataset.storyId = block.id;
    if (isFirstTabBlock) {
      article.id = `story-category-${block.tab}`;
    }
    article.style.animationDelay = `${index * 0.06}s`;
    article.innerHTML = `
      <div class="story-block-head">
        <div class="story-block-icon" style="background:${block.iconBg}">${block.icon}</div>
        <div class="story-block-copy">
          <div class="story-block-title">${block.title}</div>
          <div class="story-block-sub">${block.sub}</div>
        </div>
        <div class="story-block-pill" style="color:${block.pillColor}">${block.pill}</div>
        <div class="story-block-chevron">▾</div>
      </div>
      <div class="story-block-body"></div>
    `;

    article.querySelector('.story-block-head').addEventListener('click', () => toggleBlock(article, block));
    if (block.expanded) {
      hydrateBlock(article, block);
    }
    return article;
  }

  function toggleBlock(node, block) {
    const isExpanded = node.classList.contains('expanded');
    node.classList.toggle('expanded', !isExpanded);
    if (!isExpanded) {
      hydrateBlock(node, block);
    }
  }

  function hydrateBlock(node, block) {
    const body = node.querySelector('.story-block-body');
    if (!body || body.dataset.rendered === '1') return;
    block.render(body);
    body.dataset.rendered = '1';
  }

  function bindTabs(root) {
    root.querySelectorAll('[data-story-tab]').forEach((button) => {
      button.addEventListener('click', () => {
        setActiveTab(root, button.dataset.storyTab || 'all');
      });
    });

    root.querySelectorAll('[data-story-jump]').forEach((link) => {
      link.addEventListener('click', (event) => {
        event.preventDefault();
        const selectedTab = link.dataset.storyJump || 'all';
        setActiveTab(root, selectedTab);
        const target = root.querySelector(`#story-category-${selectedTab}`);
        if (target) {
          window.requestAnimationFrame(() => {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          });
        }
      });
    });
  }

  function setActiveTab(root, selectedTab) {
    root.querySelectorAll('[data-story-tab]').forEach((item) => {
      item.classList.toggle('active', item.dataset.storyTab === selectedTab);
    });
    root.querySelectorAll('[data-story-jump]').forEach((item) => {
      item.classList.toggle('is-active', item.dataset.storyJump === selectedTab);
    });
    root.querySelectorAll('.story-block').forEach((block) => {
      const shouldShow = selectedTab === 'all' || block.dataset.storyTab === selectedTab;
      block.classList.toggle('story-hidden', !shouldShow);
      if (shouldShow) {
        block.classList.add('visible');
      }
    });
  }

  function countBlocksForTab(tabId) {
    return STORY_BLOCKS.filter((block) => block.tab === tabId).length;
  }

  function revealVisibleBlocks() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.18 });

    document.querySelectorAll('.story-block').forEach((block) => observer.observe(block));
  }

  function mountChart(canvasId, config) {
    if (!window.Chart) return;
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    if (charts.has(canvasId)) {
      charts.get(canvasId).destroy();
      charts.delete(canvasId);
    }
    const chart = new window.Chart(canvas, config);
    charts.set(canvasId, chart);
  }

  function renderEconomyIndex(container) {
    container.innerHTML = `
      <div class="story-body-grid single">
        <div class="story-chart-card">
          <div class="story-chart-label">Сводный индекс 2019-2026: бюджет, зарплата и МСП собраны в один обзорный график вместо набора пересекающихся экономических секций.</div>
          <canvas id="story-economy-index" height="220"></canvas>
        </div>
        <div class="story-metrics-row">
          <div class="story-metric-chip"><strong>+70%</strong><span>бюджетный индекс к 2019 году</span></div>
          <div class="story-metric-chip"><strong>+54%</strong><span>рост средней зарплаты</span></div>
          <div class="story-metric-chip"><strong>+38%</strong><span>динамика сектора МСП</span></div>
        </div>
      </div>
    `;

    mountChart('story-economy-index', {
      type: 'line',
      data: {
        labels: ['2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026'],
        datasets: [
          {
            label: 'Бюджетный индекс',
            data: [100, 108, 116, 129, 140, 151, 163, 170],
            borderColor: '#00f0ff',
            backgroundColor: 'rgba(0, 240, 255, 0.14)',
            fill: true,
            tension: 0.36,
            pointRadius: 3
          },
          {
            label: 'Зарплатный индекс',
            data: [100, 103, 109, 118, 127, 138, 149, 154],
            borderColor: '#fbbf24',
            backgroundColor: 'rgba(251, 191, 36, 0.12)',
            fill: false,
            tension: 0.36,
            pointRadius: 3
          },
          {
            label: 'Индекс МСП',
            data: [100, 101, 106, 111, 118, 124, 131, 138],
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.12)',
            fill: false,
            tension: 0.36,
            pointRadius: 3
          }
        ]
      },
      options: baseChartOptions()
    });
  }

  function renderContractCycle(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-list-card">
          <div class="story-chart-label">Муниципальные контракты 2025 года: капитальный ремонт остается крупнейшим направлением, а общий объем контрактования удерживает восходящий тренд.</div>
          <div class="story-metrics-row">
            <div class="story-metric-chip"><strong>2 847</strong><span>договоров в 2025 году</span></div>
            <div class="story-metric-chip"><strong>18.4 млрд ₽</strong><span>суммарный объем контрактов</span></div>
            <div class="story-metric-chip"><strong>+52%</strong><span>рост объема к 2019 году</span></div>
          </div>
          <div class="story-chart-card" style="padding:16px 0 0">
            <canvas id="story-contract-types" height="220"></canvas>
          </div>
        </div>
        <div class="story-chart-card">
          <div class="story-chart-label">Динамика суммы муниципальных контрактов, млрд ₽</div>
          <canvas id="story-contract-sum" height="220"></canvas>
        </div>
      </div>
    `;

    mountChart('story-contract-types', {
      type: 'doughnut',
      data: {
        labels: ['Капремонт', 'Благоустройство', 'Соцобъекты', 'Инвестпроекты', 'Прочее'],
        datasets: [{
          data: [38, 24, 18, 12, 8],
          backgroundColor: ['#ec4899', '#00f0ff', '#22c55e', '#7c3aed', '#fbbf24'],
          borderColor: '#0a0c10',
          borderWidth: 3
        }]
      },
      options: {
        ...baseChartOptions(),
        cutout: '62%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: { color: '#94a3b8', usePointStyle: true, pointStyle: 'circle' }
          }
        }
      }
    });

    mountChart('story-contract-sum', {
      type: 'line',
      data: {
        labels: ['2019', '2020', '2021', '2022', '2023', '2024', '2025'],
        datasets: [{
          label: 'млрд ₽',
          data: [12.1, 11.8, 13.4, 14.9, 16.2, 17.5, 18.4],
          borderColor: '#ec4899',
          backgroundColor: 'rgba(236, 72, 153, 0.12)',
          fill: true,
          tension: 0.34,
          pointRadius: 3
        }]
      },
      options: baseChartOptions()
    });
  }

  function renderAssetCircuit(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-list-card">
          <div class="story-chart-label">Муниципальный имущественный контур показывает масштаб базы и доходность управления активами.</div>
          <div class="story-stat-grid">
            <div class="story-stat">
              <div class="story-stat-value" style="color:#fbbf24">12.8к</div>
              <div class="story-stat-label">объектов недвижимости</div>
            </div>
            <div class="story-stat">
              <div class="story-stat-value" style="color:#22c55e">5.6к</div>
              <div class="story-stat-label">земельных участков</div>
            </div>
            <div class="story-stat">
              <div class="story-stat-value" style="color:#00f0ff">3.2к</div>
              <div class="story-stat-label">единиц движимого имущества</div>
            </div>
          </div>
        </div>
        <div class="story-chart-card">
          <div class="story-chart-label">Доходы от аренды муниципального имущества, млрд ₽</div>
          <canvas id="story-rent-income" height="220"></canvas>
        </div>
      </div>
      <div class="story-body-grid" style="margin-top:14px">
        <div class="story-chart-card story-block-wide">
          <div class="story-chart-label">Приватизация объектов по годам</div>
          <canvas id="story-privatization" height="220"></canvas>
        </div>
      </div>
    `;

    mountChart('story-rent-income', {
      type: 'line',
      data: {
        labels: ['2019', '2020', '2021', '2022', '2023', '2024', '2025'],
        datasets: [{
          label: 'млрд ₽',
          data: [1.2, 1.1, 1.3, 1.5, 1.7, 1.9, 2.1],
          borderColor: '#fbbf24',
          backgroundColor: 'rgba(251, 191, 36, 0.14)',
          fill: true,
          tension: 0.36,
          pointRadius: 3
        }]
      },
      options: baseChartOptions()
    });

    mountChart('story-privatization', {
      type: 'bar',
      data: {
        labels: ['2019', '2020', '2021', '2022', '2023', '2024', '2025'],
        datasets: [{
          label: 'Объектов',
          data: [142, 118, 156, 168, 174, 189, 201],
          backgroundColor: 'rgba(59, 130, 246, 0.42)',
          borderColor: '#3b82f6',
          borderWidth: 1.2,
          borderRadius: 8
        }]
      },
      options: baseChartOptions()
    });
  }

  function renderPeopleProfile(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-chart-card">
          <div class="story-chart-label">Возрастной профиль жителей в 2025 году. Здесь оставлена компактная структура вместо повторного большого демографического раздела.</div>
          <canvas id="story-people-donut" height="220"></canvas>
        </div>
        <div class="story-list-card">
          <div class="story-chart-label">Роли внутри городской системы</div>
          <div class="story-list">
            <div class="story-list-item"><div class="story-list-meta">29%</div><div class="story-list-text">дети и молодежь формируют будущую нагрузку на образование, спорт и цифровые сервисы.</div></div>
            <div class="story-list-item"><div class="story-list-meta">56%</div><div class="story-list-text">экономически активное население удерживает основной спрос на транспорт, работу и жилье.</div></div>
            <div class="story-list-item"><div class="story-list-meta">15%</div><div class="story-list-text">старшие возрастные группы требуют отдельного фокуса на медицине, доступности и социальной поддержке.</div></div>
          </div>
        </div>
      </div>
    `;

    mountChart('story-people-donut', {
      type: 'doughnut',
      data: {
        labels: ['0-17 лет', '18-59 лет', '60+'],
        datasets: [{
          data: [29, 56, 15],
          backgroundColor: ['#00f0ff', '#7c3aed', '#fbbf24'],
          borderColor: '#0a0c10',
          borderWidth: 3,
          hoverOffset: 6
        }]
      },
      options: {
        ...baseChartOptions(),
        cutout: '64%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: { color: '#94a3b8', usePointStyle: true, pointStyle: 'circle' }
          }
        }
      }
    });
  }

  function renderSocialCore(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-list-card">
          <div class="story-chart-label">Социальная инфраструктура в одном обзоре: образование, спорт и культура без разрозненных карточек по каждой подсистеме.</div>
          <div class="story-stat-grid">
            <div class="story-stat"><div class="story-stat-value" style="color:#7c3aed">35</div><div class="story-stat-label">школ</div></div>
            <div class="story-stat"><div class="story-stat-value" style="color:#00f0ff">52</div><div class="story-stat-label">детских сада</div></div>
            <div class="story-stat"><div class="story-stat-value" style="color:#fbbf24">15</div><div class="story-stat-label">библиотек</div></div>
            <div class="story-stat"><div class="story-stat-value" style="color:#22c55e">89</div><div class="story-stat-label">спортобъектов</div></div>
            <div class="story-stat"><div class="story-stat-value" style="color:#ec4899">24</div><div class="story-stat-label">объекта культуры</div></div>
            <div class="story-stat"><div class="story-stat-value" style="color:#ff6b35">312</div><div class="story-stat-label">спортивных секций</div></div>
          </div>
        </div>
        <div class="story-chart-card">
          <div class="story-chart-label">Рост числа учащихся, тыс. человек</div>
          <canvas id="story-pupils" height="220"></canvas>
        </div>
      </div>
      <div class="story-body-grid" style="margin-top:14px">
        <div class="story-chart-card story-block-wide">
          <div class="story-chart-label">Обеспеченность социальной инфраструктурой, %</div>
          <canvas id="story-social-coverage" height="220"></canvas>
        </div>
      </div>
    `;

    mountChart('story-pupils', {
      type: 'line',
      data: {
        labels: ['2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025'],
        datasets: [{
          label: 'тыс. учащихся',
          data: [38.2, 39.1, 40.3, 41.5, 42.8, 44.1, 45.6, 47.2],
          borderColor: '#7c3aed',
          backgroundColor: 'rgba(124, 58, 237, 0.14)',
          fill: true,
          tension: 0.36,
          pointRadius: 3
        }]
      },
      options: baseChartOptions()
    });

    mountChart('story-social-coverage', {
      type: 'bar',
      data: {
        labels: ['Школы', 'Детсады', 'Культура', 'Доступная среда'],
        datasets: [{
          label: 'Обеспеченность, %',
          data: [98, 100, 91, 76],
          backgroundColor: ['rgba(0,240,255,0.42)', 'rgba(34,197,94,0.42)', 'rgba(251,191,36,0.42)', 'rgba(255,107,53,0.42)'],
          borderColor: ['#00f0ff', '#22c55e', '#fbbf24', '#ff6b35'],
          borderWidth: 1.2,
          borderRadius: 8
        }]
      },
      options: baseChartOptions({ ySuggestedMax: 100 })
    });
  }

  function renderInfraContour(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-chart-card">
          <div class="story-chart-label">Качество дорог по годам. Оставлен один чистый инфраструктурный график вместо дублирования транспорта и строительства по отдельности.</div>
          <canvas id="story-infra-roads" height="220"></canvas>
        </div>
        <div class="story-stat-grid">
          <div class="story-stat">
            <div class="story-stat-value" style="color:#22c55e">38</div>
            <div class="story-stat-label">маршрутов в опорной сети</div>
          </div>
          <div class="story-stat">
            <div class="story-stat-value" style="color:#00f0ff">412</div>
            <div class="story-stat-label">остановок в контуре города</div>
          </div>
          <div class="story-stat">
            <div class="story-stat-value" style="color:#ff6b35">74%</div>
            <div class="story-stat-label">дорог в нормативе</div>
          </div>
        </div>
      </div>
    `;

    mountChart('story-infra-roads', {
      type: 'bar',
      data: {
        labels: ['2021', '2022', '2023', '2024', '2025'],
        datasets: [{
          label: 'Доля дорог в нормативном состоянии, %',
          data: [61, 64, 67, 71, 74],
          backgroundColor: ['rgba(34,197,94,0.35)', 'rgba(34,197,94,0.42)', 'rgba(34,197,94,0.50)', 'rgba(34,197,94,0.58)', 'rgba(34,197,94,0.66)'],
          borderColor: '#22c55e',
          borderWidth: 1.2,
          borderRadius: 8
        }]
      },
      options: baseChartOptions({ ySuggestedMax: 100 })
    });
  }

  function renderHousingCycle(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-chart-card">
          <div class="story-chart-label">Разрешения на строительство, 2018-2026</div>
          <canvas id="story-permissions" height="220"></canvas>
        </div>
        <div class="story-chart-card">
          <div class="story-chart-label">Ввод жилья, тыс. м²</div>
          <canvas id="story-housing-sqm" height="220"></canvas>
        </div>
      </div>
      <div class="story-body-grid" style="margin-top:14px">
        <div class="story-chart-card">
          <div class="story-chart-label">Типология этажности нового жилого фонда</div>
          <canvas id="story-floor-dist" height="220"></canvas>
        </div>
        <div class="story-metrics-row">
          <div class="story-metric-chip"><strong>847</strong><span>объектов в строительном реестре</span></div>
          <div class="story-metric-chip"><strong>218 тыс. м²</strong><span>ввод жилья в 2025 году</span></div>
          <div class="story-metric-chip"><strong>210</strong><span>ожидаемых разрешений в 2026 году</span></div>
        </div>
      </div>
    `;

    mountChart('story-permissions', {
      type: 'bar',
      data: {
        labels: ['2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026'],
        datasets: [{
          label: 'Разрешений',
          data: [124, 138, 112, 145, 158, 167, 182, 195, 210],
          backgroundColor: 'rgba(255, 107, 53, 0.42)',
          borderColor: '#ff6b35',
          borderWidth: 1.2,
          borderRadius: 8
        }]
      },
      options: baseChartOptions()
    });

    mountChart('story-housing-sqm', {
      type: 'line',
      data: {
        labels: ['2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025'],
        datasets: [{
          label: 'тыс. м²',
          data: [142, 156, 138, 168, 175, 189, 204, 218],
          borderColor: '#22c55e',
          backgroundColor: 'rgba(34, 197, 94, 0.14)',
          fill: true,
          tension: 0.36,
          pointRadius: 3
        }]
      },
      options: baseChartOptions()
    });

    mountChart('story-floor-dist', {
      type: 'doughnut',
      data: {
        labels: ['1-5 этажей', '6-9 этажей', '10-16 этажей', '17+ этажей'],
        datasets: [{
          data: [15, 22, 38, 25],
          backgroundColor: ['#22c55e', '#00f0ff', '#7c3aed', '#ff6b35'],
          borderColor: '#0a0c10',
          borderWidth: 3
        }]
      },
      options: {
        ...baseChartOptions(),
        cutout: '60%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: { color: '#94a3b8', usePointStyle: true, pointStyle: 'circle' }
          }
        }
      }
    });
  }

  function renderCityEnvironment(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-chart-card">
          <div class="story-chart-label">Динамика переработки и объема ТКО. Блок склеивает экологию и среду в одну витрину.</div>
          <canvas id="story-city-environment" height="220"></canvas>
        </div>
        <div class="story-chart-card">
          <div class="story-chart-label">Приоритеты развития по вложенному вниманию города</div>
          <canvas id="story-city-priority" height="220"></canvas>
        </div>
      </div>
    `;

    mountChart('story-city-environment', {
      type: 'line',
      data: {
        labels: ['2021', '2022', '2023', '2024', '2025'],
        datasets: [
          {
            label: 'Переработка, %',
            data: [18, 21, 25, 29, 34],
            borderColor: '#22c55e',
            backgroundColor: 'rgba(34,197,94,0.14)',
            tension: 0.36,
            fill: true,
            yAxisID: 'y'
          },
          {
            label: 'ТКО, тыс. т',
            data: [93, 95, 97, 99, 101],
            borderColor: '#64748b',
            backgroundColor: 'rgba(100,116,139,0.10)',
            tension: 0.36,
            fill: false,
            yAxisID: 'y1'
          }
        ]
      },
      options: baseChartOptions({ dualAxis: true })
    });

    mountChart('story-city-priority', {
      type: 'doughnut',
      data: {
        labels: ['Реновация', 'Транспорт', 'Социальная сфера', 'Экология', 'Цифровые сервисы'],
        datasets: [{
          data: [26, 19, 22, 14, 19],
          backgroundColor: ['#ff6b35', '#00f0ff', '#7c3aed', '#22c55e', '#3b82f6'],
          borderColor: '#0a0c10',
          borderWidth: 3
        }]
      },
      options: {
        ...baseChartOptions(),
        cutout: '60%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: { color: '#94a3b8', usePointStyle: true, pointStyle: 'circle' }
          }
        }
      }
    });
  }

  function renderSignalsFeed(container) {
    container.innerHTML = `
      <div class="story-body-grid">
        <div class="story-list-card">
          <div class="story-chart-label">Сигналы по городу собраны в короткую редакторскую ленту: она объясняет направление движения без повторения новостных карточек из основного экрана.</div>
          <div class="story-list">
            <div class="story-list-item"><div class="story-list-meta">Транспорт</div><div class="story-list-text">Новые полосы приоритета на магистралях снижают пиковую нагрузку на автобусный каркас и повышают устойчивость расписания.</div></div>
            <div class="story-list-item"><div class="story-list-meta">Среда</div><div class="story-list-text">Фокус 2026 года смещен на связку «дворы, освещение и безбарьерная среда» вместо разрозненных локальных ремонтов.</div></div>
            <div class="story-list-item"><div class="story-list-meta">Экология</div><div class="story-list-text">Переработка растет быстрее общего объема ТКО, поэтому город начинает сокращать остаточный хвост захоронения.</div></div>
            <div class="story-list-item"><div class="story-list-meta">Цифра</div><div class="story-list-text">Карта, обращения, камеры, 3D-сцена и единая инфографика теперь работают как единый цифровой слой без разрыва на отдельные витрины.</div></div>
          </div>
        </div>
        <div class="story-metrics-row">
          <div class="story-metric-chip"><strong>Экономика</strong><span>сводный индекс и контрактный цикл</span></div>
          <div class="story-metric-chip"><strong>Соцсфера</strong><span>образование, спорт и покрытие услуг</span></div>
          <div class="story-metric-chip"><strong>История</strong><span>хронология встроена в общий аналитический экран</span></div>
        </div>
      </div>
    `;
  }

  function renderTimeline(container) {
    const items = [
      ['1909', 'Основание поселения на правом берегу Оби как транспортной и промысловой точки.'],
      ['1965', 'Нижневартовский район становится опорной базой нефтяного освоения.'],
      ['1972', 'Поселок получает статус города, и начинается быстрый промышленный рост.'],
      ['1980-е', 'Формируется каркас микрорайонов, социальных объектов и городской транспортной сети.'],
      ['2000-е', 'Город переходит от сырьевой экспансии к модернизации среды и сервисов.'],
      ['2020', 'Пандемийный стресс тестирует устойчивость демографии, логистики и бюджета.'],
      ['2025', 'Собирается цифровой контур: карта, обращения, инфографика, камеры и 3D-сцена.'],
      ['2026', 'Единый аналитический экран связывает историю, данные и живые метрики без дублей.']
    ];

    container.innerHTML = `
      <div class="story-timeline-card">
        <div class="story-chart-label">Хронология показывает, как промышленный рост, городская среда и цифровые сервисы складываются в единый контур развития.</div>
        <div class="story-timeline">
          ${items.map(([year, text], index) => `
            <div class="story-timeline-item" style="animation-delay:${index * 0.07}s">
              <div class="story-timeline-year">${year}</div>
              <div class="story-timeline-text">${text}</div>
            </div>
          `).join('')}
        </div>
      </div>
    `;
  }

  function baseChartOptions(extra = {}) {
    const options = {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 900, easing: 'easeOutQuart' },
      plugins: {
        legend: {
          labels: {
            color: '#94a3b8',
            usePointStyle: true,
            pointStyle: 'circle',
            boxWidth: 10,
            padding: 14
          }
        },
        tooltip: {
          backgroundColor: 'rgba(15, 23, 42, 0.92)',
          titleColor: '#f8fafc',
          bodyColor: '#cbd5e1',
          borderColor: 'rgba(0, 240, 255, 0.18)',
          borderWidth: 1
        }
      },
      scales: {
        x: {
          ticks: { color: '#64748b' },
          grid: { color: 'rgba(148,163,184,0.08)' }
        },
        y: {
          ticks: { color: '#64748b' },
          grid: { color: 'rgba(148,163,184,0.08)' }
        }
      }
    };

    if (extra.ySuggestedMax) {
      options.scales.y.suggestedMax = extra.ySuggestedMax;
    }

    if (extra.dualAxis) {
      options.scales.y1 = {
        position: 'right',
        ticks: { color: '#64748b' },
        grid: { drawOnChartArea: false }
      };
    }

    return options;
  }

  document.addEventListener('DOMContentLoaded', renderUnifiedStory);
})();
