/**
 * 노드라인 (Nodeline) v1.0.0 — 노르딕 아키텍처 라이트
 * HTML5 Canvas 시뮬레이션 엔진
 */

(function () {
  'use strict';

  // ==========================================================================
  // 1. 설정 상수 (Game Config)
  // ==========================================================================
  const APP_NAME = '노드라인 (Nodeline)';
  const APP_VERSION = '1.0.0';
  window.NODELINE_VERSION = APP_VERSION;

  const CONFIG = {
    app: {
      name: APP_NAME,
      version: APP_VERSION
    },
    grid: {
      cellSizePx: 64,       // 그리드 1칸 한 변 픽셀 = 1m (1m × 1m 격자)
      cellSideMeters: 1     // 1칸 한 변 = 1m
    },
    playArea: { width: 1600, height: 896, margin: 100 },
    station: {
      maxLines: 5,
      maxPassengers: 30,    // 30명 도달 시 1초 유예 후 게임오버
      overflowGraceSec: 1.0, // 30명 도달 시 유예 시간 (게임 배속 비례)
      warn1Threshold: 27,   // 27명 도달 시 1차 경고
      warn2Threshold: 28,   // 28명 도달 시 2차 경고
      warn3Threshold: 29,   // 29명 도달 시 3차 경고
      minDistance: 160,
      radius: 20
    },
    train: {
      stationToTrainRatio: 1 / 2, // 역 최대 수용 인원(30명) : 열차 최대 수용 인원(15명) = 2 : 1
      baseSpeed: 130,
      crossingSpeedMultiplier: 0.6,
      crossingRadius: 24,
      stopDuration: 1.4
    },
    resources: {
      initialLines: 3,
      initialTrains: 1,
      initialBridges: 1,
      initialTunnels: 1
    },
    simulation: {
      startHour: 0,               // Day 0 · 00:00 시작 -> 24시간 경과마다 즉시 날짜 변경
      dayDurationRealSec: 60,     // 1일(24시간) = 실시간 60초(1분)
      minSpeed: 1,                // 배속 최솟값 (1배속)
      maxSpeed: 10,               // 배속 최댓값 (10배속)
      bridgeSupplyDays: 1,        // 1일마다 다리 +1 지급
      tunnelSupplyDays: 2,        // 2일마다 터널 +1 지급
      mapExpansionDays: 7,        // 1주일(7일)마다 지도 확장 및 주간 보급 선택
      mapExpansionRate: 1 / 6,    // 매주 가로·세로 각각 1/6 확장
      stationBaseSpawnHours: 24,
      stationBonusCheckHours: 12,
      stationBonusChance: 0.25,
      maxNaturalStations: 24,
      maxRequiredInfrastructure: 1
    },
    cursor: {
      luminanceThreshold: 0.50
    },
    colors: {
      paper: '#F8F6F0',
      grid: 'rgba(226, 221, 211, 0.8)',
      river: '#A2C5DC',
      riverBank: '#5A8AA8',
      mountain: '#DCE3DB',
      mountainStroke: '#9DB09B',
      stationOutline: '#1E293B',
      linePalette: [
        '#15529E', // 1호선 코발트 블루
        '#D84315', // 2호선 코랄 레드
        '#2E7D32', // 3호선 포레스트 그린
        '#6A1B9A', // 4호선 로열 바이올렛
        '#EF6C00', // 5호선 골든 앰버
        '#00838F', // 6호선 딥 틸
        '#AD1457', // 7호선 크림슨 마젠타
        '#283593', // 8호선 인디고 네이비
        '#558B2F'  // 9호선 올리브 그린
      ],
      stationColors: [
        '#1D5299',
        '#D84315',
        '#2E7D32'
      ]
    }
  };

  const SHAPES = {
    CIRCLE: 'circle',
    TRIANGLE: 'triangle',
    SQUARE: 'square'
  };

  // ==========================================================================
  // 2. 오디오 신디사이저 (Web Audio API)
  // ==========================================================================
  class SoundFX {
    constructor() {
      this.ctx = null;
      this.enabled = true;
    }

    init() {
      if (!this.ctx) {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (AudioCtx) this.ctx = new AudioCtx();
      }
      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }
    }

    toggle() {
      this.enabled = !this.enabled;
      return this.enabled;
    }

    play(type) {
      if (!this.enabled) return;
      this.init();
      if (!this.ctx) return;

      const t = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.connect(gain);
      gain.connect(this.ctx.destination);

      if (type === 'click') {
        osc.frequency.setValueAtTime(480, t);
        osc.frequency.exponentialRampToValueAtTime(760, t + 0.045);
        gain.gain.setValueAtTime(0.09, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.045);
        osc.start(t);
        osc.stop(t + 0.045);
      } else if (type === 'connect') {
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(523.25, t);
        osc.frequency.setValueAtTime(659.25, t + 0.07);
        osc.frequency.setValueAtTime(783.99, t + 0.14);
        gain.gain.setValueAtTime(0.15, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.28);
        osc.start(t);
        osc.stop(t + 0.28);
      } else if (type === 'arrive') {
        osc.type = 'sine';
        osc.frequency.setValueAtTime(840, t);
        gain.gain.setValueAtTime(0.07, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
        osc.start(t);
        osc.stop(t + 0.12);
      } else if (type === 'warn' || type === 'warn1') {
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(420, t);
        osc.frequency.setValueAtTime(350, t + 0.08);
        gain.gain.setValueAtTime(0.13, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.19);
        osc.start(t);
        osc.stop(t + 0.19);
      } else if (type === 'warn2') {
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(520, t);
        osc.frequency.setValueAtTime(390, t + 0.09);
        osc.frequency.setValueAtTime(520, t + 0.17);
        gain.gain.setValueAtTime(0.14, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.27);
        osc.start(t);
        osc.stop(t + 0.27);
      } else if (type === 'warn3') {
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(660, t);
        osc.frequency.setValueAtTime(440, t + 0.08);
        osc.frequency.setValueAtTime(660, t + 0.16);
        osc.frequency.setValueAtTime(440, t + 0.24);
        gain.gain.setValueAtTime(0.16, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.34);
        osc.start(t);
        osc.stop(t + 0.34);
      } else if (type === 'gameover') {
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(280, t);
        osc.frequency.exponentialRampToValueAtTime(85, t + 0.7);
        gain.gain.setValueAtTime(0.2, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.7);
        osc.start(t);
        osc.stop(t + 0.7);
      }
    }
  }

  // ==========================================================================
  // 3. 기하학 및 색상 판정 유틸리티
  // ==========================================================================
  const Geometry = {
    dist(p1, p2) {
      return Math.hypot(p1.x - p2.x, p1.y - p2.y);
    },

    pointInPolygon(point, vs) {
      const x = point.x, y = point.y;
      let inside = false;
      for (let i = 0, j = vs.length - 1; i < vs.length; j = i++) {
        const xi = vs[i].x, yi = vs[i].y;
        const xj = vs[j].x, yj = vs[j].y;
        const intersect = ((yi > y) !== (yj > y)) &&
            (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
      }
      return inside;
    },

    linesIntersect(p1, p2, p3, p4) {
      function ccw(A, B, C) {
        return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x);
      }
      return (ccw(p1, p3, p4) !== ccw(p2, p3, p4)) && (ccw(p1, p2, p3) !== ccw(p1, p2, p4));
    },

    segmentIntersectionPoint(p1, p2, p3, p4) {
      const denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x);
      if (Math.abs(denom) < 1e-9) return null;
      const t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom;
      const u = -((p1.x - p2.x) * (p1.y - p3.y) - (p1.y - p2.y) * (p1.x - p3.x)) / denom;
      if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
        return {
          x: p1.x + t * (p2.x - p1.x),
          y: p1.y + t * (p2.y - p1.y)
        };
      }
      return null;
    },

    segmentIntersectsPolygon(p1, p2, poly) {
      for (let i = 0; i < poly.length; i++) {
        if (Geometry.linesIntersect(p1, p2, poly[i], poly[(i + 1) % poly.length])) return true;
      }
      return false;
    },

    pointToSegmentDist(p, a, b) {
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const lenSq = dx * dx + dy * dy;
      if (lenSq < 1e-9) {
        return { dist: Math.hypot(p.x - a.x, p.y - a.y), proj: { x: a.x, y: a.y } };
      }
      const t = Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq));
      const proj = { x: a.x + t * dx, y: a.y + t * dy };
      return { dist: Math.hypot(p.x - proj.x, p.y - proj.y), proj };
    },

    segmentPolygonCenter(p1, p2, poly) {
      const hits = [];
      for (let i = 0; i < poly.length; i++) {
        const pt = Geometry.segmentIntersectionPoint(p1, p2, poly[i], poly[(i + 1) % poly.length]);
        if (pt) hits.push(pt);
      }
      if (hits.length === 0) {
        return { x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5 };
      }
      let sx = 0, sy = 0;
      for (const h of hits) {
        sx += h.x;
        sy += h.y;
      }
      return { x: sx / hits.length, y: sy / hits.length };
    },

    parseCssRgba(str) {
      if (!str || str === 'transparent') return null;
      const m = str.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\s*\)/i);
      if (!m) return null;
      return {
        r: Number(m[1]),
        g: Number(m[2]),
        b: Number(m[3]),
        a: m[4] === undefined ? 1 : Number(m[4])
      };
    }
  };

  // ==========================================================================
  // 4. 메인 게임 클래스 (SubwayGame)
  // ==========================================================================
  class SubwayGame {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d', { willReadFrequently: true }) || canvas.getContext('2d');
      this.sfx = new SoundFX();

      this.camera = {
        x: CONFIG.playArea.margin + CONFIG.playArea.width * 0.5,
        y: CONFIG.playArea.margin + CONFIG.playArea.height * 0.5,
        zoom: 0.95
      };

      this.startSimTime = CONFIG.simulation.startHour * 3600;
      this.simTime = this.startSimTime;
      this.speed = 1;
      this.isPaused = false;
      this.isGameOver = false;
      this.isRewardModalOpen = false;
      this.isControlsGuideOpen = true; // 최초 접속 시 조작법 가이드 모달 표시
      this.pendingWeeklyRewards = 0;

      // Q+(숫자) 배속 제어 상태 (1~10배속)
      this.isQKeyDown = false;
      this.isQSpeedModeActive = false;
      this.qSpeedModeTimeout = null;
      this.lastQDigit = null;
      this.lastQDigitTime = 0;

      // 호선 및 자원 상태
      this.activeLineSlot = 1;
      this.resetResources();

      this.score = 0;
      this.totalArrivedPassengers = 0;
      this.eventLogs = [];

      this.stations = [];
      this.lines = [];
      this.trains = [];
      this.terrains = [];
      this.bridges = [];
      this.tunnels = [];
      this.crossingPoints = [];

      // 인터랙션 및 커서 상태
      this.connectingFromStation = null;
      this.hoveredStation = null;
      this.selectedStation = null;
      this.isDraggingCamera = false;
      this.dragStartPos = { x: 0, y: 0 };
      this.mouseWorldPos = { x: 0, y: 0 };
      this.mouseScreenPos = { x: -1, y: -1 };
      this.isCursorWhite = false;
      this.showLastStationMarkers = false;
      this.showFirstStationMarkers = false;
      this.isDeleteMode = false;
      this.hoveredDeleteSegment = null;
      this._renderedSlotCount = -1;
      this.canvasFontFamily = '"Pretendard", sans-serif';
      this.canvasMonoFontFamily = '"JetBrains Mono", monospace';

      this.undoStack = [];
      this.redoStack = [];

      this.playArea = {
        width: CONFIG.playArea.width,
        height: CONFIG.playArea.height,
        margin: CONFIG.playArea.margin,
        centerX: CONFIG.playArea.margin + CONFIG.playArea.width * 0.5,
        centerY: CONFIG.playArea.margin + CONFIG.playArea.height * 0.5,
        expansionWeek: 0
      };

      this.lastBaseSpawnCycle = 0;
      this.lastBonusSpawnCycle = 0;
      this.lastBridgeSupplyCycle = 0;
      this.lastTunnelSupplyCycle = 0;
      this.lastRecordedDay = 0;

      this.resize();
      this.initFontPreference();
      this.initEvents();
      this.initMap();
      window.addEventListener('resize', () => this.resize());
    }

    initFontPreference() {
      let saved = 'pretendard';
      try {
        const stored = localStorage.getItem('subway_font_preset');
        if (stored) saved = stored;
      } catch (_) {}
      this.setFontPreset(saved, false);
    }

    setFontPreset(key, showFeedback = true) {
      const presets = {
        jua: {
          label: '주아체 (뭉툭)',
          main: "'Jua', sans-serif",
          mono: "'Jua', 'JetBrains Mono', monospace",
          canvas: '"Jua", sans-serif',
          canvasMono: '"Jua", monospace'
        },
        dohyeon: {
          label: '도현체 (각짐)',
          main: "'Do Hyeon', sans-serif",
          mono: "'Do Hyeon', 'JetBrains Mono', monospace",
          canvas: '"Do Hyeon", sans-serif',
          canvasMono: '"Do Hyeon", monospace'
        },
        galmuri: {
          label: '갈무리11 (도트)',
          main: "'Galmuri11', monospace",
          mono: "'Galmuri11', monospace",
          canvas: '"Galmuri11", monospace',
          canvasMono: '"Galmuri11", monospace'
        },
        batang: {
          label: '고운바탕 (명조)',
          main: "'Gowun Batang', serif",
          mono: "'JetBrains Mono', monospace",
          canvas: '"Gowun Batang", serif',
          canvasMono: '"JetBrains Mono", monospace'
        },
        pretendard: {
          label: '프리텐다드 (기본)',
          main: "'Pretendard', 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif",
          mono: "'JetBrains Mono', monospace",
          canvas: '"Pretendard", sans-serif',
          canvasMono: '"JetBrains Mono", monospace'
        }
      };

      const preset = presets[key] || presets.pretendard;
      const activeKey = presets[key] ? key : 'pretendard';

      document.documentElement.style.setProperty('--font-main', preset.main);
      document.documentElement.style.setProperty('--font-mono', preset.mono);
      this.canvasFontFamily = preset.canvas;
      this.canvasMonoFontFamily = preset.canvasMono;

      try {
        localStorage.setItem('subway_font_preset', activeKey);
      } catch (_) {}

      const buttons = document.querySelectorAll('#fontPickerGrid .font-option');
      buttons.forEach(btn => {
        btn.classList.toggle('active', btn.dataset.font === activeKey);
      });

      if (showFeedback) {
        this.sfx.play('click');
        this.showToast(`글씨체 적용: ${preset.label}`);
      }
    }

    resetResources() {
      this.availableLines = CONFIG.resources.initialLines;
      this.availableTrains = CONFIG.resources.initialTrains;
      this.extraPendingTrains = 0;
      this.availableBridges = CONFIG.resources.initialBridges;
      this.availableTunnels = CONFIG.resources.initialTunnels;
      this.activeLineSlot = 1;
    }

    /**
     * 역 최대 수용 인원(30명) : 열차 최대 수용 인원(15명) = 2 : 1 (반올림 정수 적용)
     */
    getTrainMaxCapacity() {
      return Math.round(CONFIG.station.maxPassengers * CONFIG.train.stationToTrainRatio);
    }

    getCurrentDay() {
      const elapsedSec = Math.max(0, this.simTime - this.startSimTime);
      return Math.floor(elapsedSec / 86400);
    }

    getPlayAreaMetrics() {
      const expandPct = Math.round(((this.playArea.width / CONFIG.playArea.width) - 1) * 100);
      return { expandPct };
    }

    resize() {
      this.canvas.width = window.innerWidth;
      this.canvas.height = window.innerHeight;
    }

    getSlotColor(slot) {
      const palette = CONFIG.colors.linePalette;
      return palette[(slot - 1) % palette.length];
    }

    getLineBySlot(slot) {
      return this.lines.find(l => l.slot === slot) || null;
    }

    findFirstUnusedSlot() {
      for (let s = 1; s <= this.availableLines; s++) {
        if (!this.getLineBySlot(s)) return s;
      }
      return null;
    }

    initMap() {
      this.terrains = [];
      this.stations = [];
      this.lines = [];
      this.trains = [];
      this.bridges = [];
      this.tunnels = [];
      this.crossingPoints = [];
      this.undoStack = [];
      this.redoStack = [];

      this.totalArrivedPassengers = 0;
      this.score = 0;
      this.startSimTime = CONFIG.simulation.startHour * 3600;
      this.simTime = this.startSimTime;
      this.isGameOver = false;
      this.isRewardModalOpen = false;
      this.pendingWeeklyRewards = 0;

      this.connectingFromStation = null;
      this.selectedStation = null;
      this.hoveredStation = null;
      this._renderedSlotCount = -1;

      this.resetResources();

      const inspector = document.getElementById('inspectorPanel');
      if (inspector) inspector.classList.add('hidden');
      const banner = document.getElementById('connectingBanner');
      if (banner) banner.classList.add('hidden');
      const warnBanner = document.getElementById('warningBanner');
      if (warnBanner) warnBanner.classList.add('hidden');
      const rewardModal = document.getElementById('weeklyRewardModal');
      if (rewardModal) rewardModal.classList.add('hidden');

      this.showLastStationMarkers = false;
      this.showFirstStationMarkers = false;
      this.isDeleteMode = false;
      this.hoveredDeleteSegment = null;
      const btnLast = document.getElementById('btnToolLastStation');
      if (btnLast) btnLast.classList.remove('active');
      const btnFirst = document.getElementById('btnToolFirstStation');
      if (btnFirst) btnFirst.classList.remove('active');
      const btnDel = document.getElementById('btnToolDeleteLine');
      if (btnDel) btnDel.classList.remove('active');
      const btnLine = document.getElementById('btnToolLine');
      if (btnLine) btnLine.classList.add('active');

      this.playArea = {
        width: CONFIG.playArea.width,
        height: CONFIG.playArea.height,
        margin: CONFIG.playArea.margin,
        centerX: CONFIG.playArea.margin + CONFIG.playArea.width * 0.5,
        centerY: CONFIG.playArea.margin + CONFIG.playArea.height * 0.5,
        expansionWeek: 0
      };

      this.lastBaseSpawnCycle = 0;
      this.lastBonusSpawnCycle = 0;
      this.lastBridgeSupplyCycle = 0;
      this.lastTunnelSupplyCycle = 0;
      this.lastRecordedDay = 0;

      const area = this.playArea;

      // 1. 강 지형 생성 (y축 중심 0 기준, -75~75 범위 내 자연스러운 랜덤 곡선)
      this.terrains.push(this.generateRiver(area));

      // 2. 산악 지형 생성
      this.terrains.push(this.generateMountain({ x: area.margin + area.width * 0.78, y: area.margin + 220 }, 130, 85));
      this.terrains.push(this.generateMountain({ x: area.margin + area.width * 0.22, y: area.margin + area.height - 180 }, 120, 80));

      // 3. 초기 3개 역 무장애 생성
      this.generateInitialStations();

      const trainCap = this.getTrainMaxCapacity();
      this.logEvent(`운행 준비 완료 — 열차 정원 ${trainCap}명 · 역 한도 ${CONFIG.station.maxPassengers}명`);
      this.updateHUD();
    }

    /**
     * 강 지형 생성:
     * - 맵 세로 중앙(area.centerY)을 y축 0 기준선으로 설정
     * - 가로 정중앙은 y축 0에 수렴하고, 좌우 구간은 -75 ~ +75 범위 내에서 랜덤 굴곡
     * - 다중 주파수 코사인 보간 곡선으로 단조로움을 탈피하고 자연스러운 물줄기 형성
     */
    generateRiver(area) {
      const riverCenterY = area.centerY || (area.margin + area.height * 0.5);
      const minX = (area.centerX ? area.centerX - area.width * 0.5 : area.margin);
      const maxX = (area.centerX ? area.centerX + area.width * 0.5 : area.margin + area.width);
      const totalWidth = maxX - minX;

      const segments = 16;
      const segWidth = totalWidth / segments;
      const riverWidth = 55;

      // 5개 제어점: 맨 가운데(index 2)는 y축 0, 나머지는 -75 ~ +75 범위의 독립 난수
      const keyPoints = [
        (Math.random() * 2 - 1) * 75,
        (Math.random() * 2 - 1) * 75,
        0, // 맨 가운데는 y축 0
        (Math.random() * 2 - 1) * 75,
        (Math.random() * 2 - 1) * 75
      ];

      const wavePhase1 = Math.random() * Math.PI * 2;
      const wavePhase2 = Math.random() * Math.PI * 2;

      const topPts = [];
      const botPts = [];

      for (let i = 0; i <= segments; i++) {
        const t = i / segments;
        const x = minX + i * segWidth;

        // 제어점 간 스무스 코사인 보간
        const keyT = t * (keyPoints.length - 1);
        const k0 = Math.floor(keyT);
        const k1 = Math.min(keyPoints.length - 1, k0 + 1);
        const frac = keyT - k0;
        const smoothFrac = (1 - Math.cos(frac * Math.PI)) * 0.5;
        const baseOffset = keyPoints[k0] * (1 - smoothFrac) + keyPoints[k1] * smoothFrac;

        // 자연스러운 물결 잔물결 합성
        const microWave = Math.sin(t * Math.PI * 2.5 + wavePhase1) * 8 +
                          Math.sin(t * Math.PI * 4.5 + wavePhase2) * 5;

        // 맵 중앙(t = 0.5)은 0을 정밀하게 통과하도록 감쇠
        const distFromCenter = Math.abs(t - 0.5);
        const centerFactor = Math.min(1, distFromCenter / 0.15);
        let offset = baseOffset + microWave * centerFactor;

        // -75 ~ +75 범위 엄격 클램핑
        offset = Math.max(-75, Math.min(75, offset));

        const y = riverCenterY + offset;
        topPts.push({ x, y: y - riverWidth * 0.5 });
        botPts.push({ x, y: y + riverWidth * 0.5 });
      }

      return {
        id: 'river_0',
        type: 'RIVER',
        polygon: [...topPts, ...botPts.reverse()]
      };
    }

    generateMountain(center, rx, ry) {
      const points = [];
      const count = 12;
      for (let i = 0; i < count; i++) {
        const angle = (i / count) * Math.PI * 2;
        const noise = 0.85 + Math.sin(i * 3.5) * 0.15;
        points.push({
          x: center.x + Math.cos(angle) * rx * noise,
          y: center.y + Math.sin(angle) * ry * noise
        });
      }
      return {
        id: 'mountain_' + Math.random().toString(36).slice(2, 7),
        type: 'MOUNTAIN',
        polygon: points
      };
    }

    generateInitialStations() {
      const area = CONFIG.playArea;
      const shapes = [SHAPES.CIRCLE, SHAPES.TRIANGLE, SHAPES.SQUARE];
      const colors = [...CONFIG.colors.stationColors];

      const centerY = area.margin + area.height * 0.28;
      const centerX = area.margin + area.width * 0.5;
      const positions = [
        { x: centerX - 180, y: centerY + 30 },
        { x: centerX + 180, y: centerY + 20 },
        { x: centerX + 10, y: centerY - 120 }
      ];

      for (let i = 0; i < 3; i++) {
        this.stations.push({
          id: `s_00${i + 1}`,
          name: `역 ${String(i + 1).padStart(2, '0')}`,
          position: positions[i],
          shape: shapes[i],
          color: colors[i],
          passengers: [],
          connectedLineIds: [],
          warningStage: 0
        });
      }
    }

    // ==========================================================================
    // 5. 호선 선택 및 노선 연결 규칙 (순환선 보존 + 분기 노선 지원)
    // ==========================================================================
    selectLineSlot(slotNum) {
      if (slotNum < 1 || slotNum > this.availableLines) {
        this.showToast(`${slotNum}호선은 아직 개방되지 않았습니다 (현재 1~${this.availableLines}호선 사용 가능)`);
        this.sfx.play('warn');
        return;
      }
      this.activeLineSlot = slotNum;
      const existing = this.getLineBySlot(slotNum);
      const statusText = existing
        ? (existing.isCircular ? `${existing.name} (순환 운행 중 · 연결 시 여분 호선으로 분기)` : `${existing.name} 연장 모드`)
        : `${slotNum}호선 신설 대기`;
      this.showToast(`호선 선택: ${statusText}`);
      this.sfx.play('click');

      if (this.connectingFromStation) {
        this.showConnectingBanner(this.connectingFromStation);
      } else if (this.isDeleteMode) {
        this.showDeleteModeBanner();
      }
      this.updateHUD();
    }

    isSegmentOnLine(line, idA, idB) {
      const ids = line.stationIds;
      for (let i = 0; i < ids.length - 1; i++) {
        if ((ids[i] === idA && ids[i + 1] === idB) || (ids[i] === idB && ids[i + 1] === idA)) {
          return true;
        }
      }
      if (line.isCircular && ids.length >= 3) {
        const first = ids[0];
        const last = ids[ids.length - 1];
        if ((first === idA && last === idB) || (first === idB && last === idA)) {
          return true;
        }
      }
      return false;
    }

    canExtendNonCircularLine(line, origFrom, origTo) {
      if (!line || line.isCircular || line.stationIds.length < 2) return null;
      const firstId = line.stationIds[0];
      const lastId = line.stationIds[line.stationIds.length - 1];

      if (origTo) {
        if (line.stationIds.length >= 3 &&
            ((origFrom.id === firstId && origTo.id === lastId) ||
             (origFrom.id === lastId && origTo.id === firstId))) {
          return { mode: 'CLOSE_LOOP', line, slot: line.slot, color: line.color, lineName: line.name };
        }
        if (lastId === origFrom.id && !line.stationIds.includes(origTo.id)) {
          return { mode: 'EXTEND', line, isFront: false, stationToAdd: origTo, slot: line.slot, color: line.color, lineName: line.name };
        }
        if (firstId === origFrom.id && !line.stationIds.includes(origTo.id)) {
          return { mode: 'EXTEND', line, isFront: true, stationToAdd: origTo, slot: line.slot, color: line.color, lineName: line.name };
        }
        if (lastId === origTo.id && !line.stationIds.includes(origFrom.id)) {
          return { mode: 'EXTEND', line, isFront: false, stationToAdd: origFrom, slot: line.slot, color: line.color, lineName: line.name };
        }
        if (firstId === origTo.id && !line.stationIds.includes(origFrom.id)) {
          return { mode: 'EXTEND', line, isFront: true, stationToAdd: origFrom, slot: line.slot, color: line.color, lineName: line.name };
        }
        return null;
      }

      if (origFrom.id === firstId || origFrom.id === lastId) {
        return { mode: 'EXTEND', line, slot: line.slot, color: line.color, lineName: line.name };
      }
      return null;
    }

    /**
     * 현재 선택된 호선(activeLineSlot)과 시작/목표 역을 기준으로 연결 계획을 판정한다.
     * 핵심 규칙: 이미 순환선(isCircular)인 노선은 절대 깨뜨리지 않고 그대로 유지하며,
     * 여분 호선(신규 노선) 또는 연장 가능한 다른 비순환 노선으로 분기 연결한다.
     */
    resolveConnectionPlan(origFrom, origTo = null) {
      const slot = this.activeLineSlot;
      const selectedLine = this.getLineBySlot(slot);

      // 1) 선택된 호선이 아직 개설 전이면 해당 호선으로 즉시 신설
      if (!selectedLine) {
        return {
          ok: true,
          mode: 'NEW_LINE',
          slot,
          color: this.getSlotColor(slot),
          lineName: `${slot}호선`
        };
      }

      // 2) 선택된 호선이 이미 완성된 순환선이면 순환선을 보존하고 다른 노선으로 분기
      if (selectedLine.isCircular) {
        const emptySlot = this.findFirstUnusedSlot();
        if (emptySlot !== null) {
          return {
            ok: true,
            mode: 'NEW_LINE',
            branchedFromCircular: selectedLine.name,
            slot: emptySlot,
            color: this.getSlotColor(emptySlot),
            lineName: `${emptySlot}호선`
          };
        }

        // 모든 슬롯이 개통된 상태라면 연장 가능한 다른 비순환 노선이 있는지 탐색
        for (const other of this.lines) {
          if (other.isCircular) continue;
          const ext = this.canExtendNonCircularLine(other, origFrom, origTo);
          if (ext) {
            return { ok: true, ...ext, branchedFromCircular: selectedLine.name };
          }
        }

        return {
          ok: false,
          reason: `${selectedLine.name} 순환선 유지 — 분기할 빈 호선이 없습니다`,
          slot,
          color: '#C92A2A',
          lineName: selectedLine.name
        };
      }

      // 3) 선택된 호선이 비순환 노선인 경우 끝점 연장 우선 판정
      const extPlan = this.canExtendNonCircularLine(selectedLine, origFrom, origTo);
      if (extPlan) {
        return { ok: true, ...extPlan };
      }

      // 4) 순환선에 속한 역에서 다른 역으로 이을 때 선택 호선과 이어지지 않으면 여분 호선으로 자동 분기
      const circularAtOrigin = this.lines.find(l => l.isCircular && l.stationIds.includes(origFrom.id));
      const circularAtTarget = origTo ? this.lines.find(l => l.isCircular && l.stationIds.includes(origTo.id)) : null;
      const sourceCircular = circularAtOrigin || circularAtTarget;
      if (sourceCircular) {
        const emptySlot = this.findFirstUnusedSlot();
        if (emptySlot !== null) {
          return {
            ok: true,
            mode: 'NEW_LINE',
            branchedFromCircular: sourceCircular.name,
            slot: emptySlot,
            color: this.getSlotColor(emptySlot),
            lineName: `${emptySlot}호선`
          };
        }
      }

      return {
        ok: false,
        reason: `${selectedLine.name} 끝 역에서만 연장 가능 (숫자 1~${this.availableLines} 키로 호선 변경)`,
        slot,
        color: '#C92A2A',
        lineName: selectedLine.name
      };
    }

    captureNetworkSnapshot() {
      const stationConnections = {};
      for (const st of this.stations) {
        stationConnections[st.id] = [...st.connectedLineIds];
      }
      return {
        activeLineSlot: this.activeLineSlot,
        availableLines: this.availableLines,
        availableTrains: this.availableTrains,
        extraPendingTrains: this.extraPendingTrains,
        availableBridges: this.availableBridges,
        availableTunnels: this.availableTunnels,
        lines: this.lines.map(l => ({
          id: l.id,
          slot: l.slot,
          name: l.name,
          color: l.color,
          stationIds: [...l.stationIds],
          lastConnectedStationId: l.lastConnectedStationId || null,
          isCircular: l.isCircular
        })),
        trains: this.trains.map(t => ({
          id: t.id,
          lineId: t.lineId,
          currentStationIndex: t.currentStationIndex,
          direction: t.direction,
          progress: t.progress,
          passengers: [...t.passengers],
          state: t.state,
          stopTimer: t.stopTimer
        })),
        bridges: this.bridges.map(b => ({
          id: b.id,
          pos: { x: b.pos.x, y: b.pos.y },
          lineId: b.lineId || null,
          segA: b.segA || null,
          segB: b.segB || null
        })),
        tunnels: this.tunnels.map(t => ({
          id: t.id,
          pos: { x: t.pos.x, y: t.pos.y },
          lineId: t.lineId || null,
          segA: t.segA || null,
          segB: t.segB || null
        })),
        stationConnections
      };
    }

    restoreNetworkSnapshot(snap) {
      this.activeLineSlot = snap.activeLineSlot;
      this.availableLines = snap.availableLines;
      this.availableTrains = snap.availableTrains;
      this.extraPendingTrains = snap.extraPendingTrains || 0;
      this.availableBridges = snap.availableBridges;
      this.availableTunnels = snap.availableTunnels;

      this.lines = snap.lines.map(l => ({
        id: l.id,
        slot: l.slot,
        name: l.name,
        color: l.color,
        stationIds: [...l.stationIds],
        lastConnectedStationId: l.lastConnectedStationId || null,
        isCircular: l.isCircular
      }));
      this.bridges = snap.bridges.map(b => ({
        id: b.id,
        pos: { x: b.pos.x, y: b.pos.y },
        lineId: b.lineId || null,
        segA: b.segA || null,
        segB: b.segB || null
      }));
      this.tunnels = snap.tunnels.map(t => ({
        id: t.id,
        pos: { x: t.pos.x, y: t.pos.y },
        lineId: t.lineId || null,
        segA: t.segA || null,
        segB: t.segB || null
      }));

      for (const st of this.stations) {
        st.connectedLineIds = snap.stationConnections[st.id] ? [...snap.stationConnections[st.id]] : [];
      }

      this.trains = snap.trains.map(t => ({
        id: t.id,
        lineId: t.lineId,
        currentStationIndex: t.currentStationIndex,
        direction: t.direction,
        progress: t.progress,
        passengers: [...t.passengers],
        state: t.state,
        stopTimer: t.stopTimer
      }));

      this.rebuildCrossings();
      this._renderedSlotCount = -1;
      this.updateHUD();
    }

    undo() {
      if (this.undoStack.length === 0) {
        this.showToast("실행 취소할 내역이 없습니다.");
        return;
      }
      const prev = this.undoStack.pop();
      this.redoStack.push(this.captureNetworkSnapshot());
      this.restoreNetworkSnapshot(prev);
      this.sfx.play('click');
      this.logEvent(`실행 취소 — 보유 다리 ${this.availableBridges} · 터널 ${this.availableTunnels}`);
      this.showToast(`실행 취소 완료 (다리 ${this.availableBridges} · 터널 ${this.availableTunnels})`);
    }

    redo() {
      if (this.redoStack.length === 0) {
        this.showToast("다시 실행할 내역이 없습니다.");
        return;
      }
      const next = this.redoStack.pop();
      this.undoStack.push(this.captureNetworkSnapshot());
      this.restoreNetworkSnapshot(next);
      this.sfx.play('click');
      this.logEvent(`다시 실행 — 보유 다리 ${this.availableBridges} · 터널 ${this.availableTunnels}`);
      this.showToast(`다시 실행 완료 (다리 ${this.availableBridges} · 터널 ${this.availableTunnels})`);
    }

    connectStations(fromStation, toStation) {
      if (!fromStation || !toStation || fromStation.id === toStation.id) return;

      const origFrom = fromStation;
      const origTo = toStation;
      const plan = this.resolveConnectionPlan(origFrom, origTo);

      if (!plan.ok) {
        this.showToast(plan.reason);
        this.sfx.play('warn');
        return;
      }

      // 동일 호선 내 중복 구간 검사
      const targetExisting = plan.line || this.getLineBySlot(plan.slot);
      if (targetExisting && this.isSegmentOnLine(targetExisting, origFrom.id, origTo.id)) {
        this.showToast(`${targetExisting.name}에 이미 연결된 구간입니다.`);
        this.sfx.play('warn');
        return;
      }

      // 역당 5개 노선 한도 검사 (새로 역에 추가되는 경우만 확인)
      if (plan.mode === 'NEW_LINE') {
        if (origFrom.connectedLineIds.length >= CONFIG.station.maxLines ||
            origTo.connectedLineIds.length >= CONFIG.station.maxLines) {
          this.showToast(`역당 최대 ${CONFIG.station.maxLines}개 노선까지만 연결할 수 있습니다.`);
          this.sfx.play('warn');
          return;
        }
      } else if (plan.mode === 'EXTEND') {
        if (plan.stationToAdd.connectedLineIds.length >= CONFIG.station.maxLines) {
          this.showToast(`역당 최대 ${CONFIG.station.maxLines}개 노선까지만 연결할 수 있습니다.`);
          this.sfx.play('warn');
          return;
        }
      }

      // 지형 통과 인프라 보유량 검사
      const terrainCheck = this.checkSegmentTerrain(origFrom.position, origTo.position);
      if (terrainCheck.bridgeCount > this.availableBridges) {
        this.showToast(`다리가 부족합니다 (필요 ${terrainCheck.bridgeCount} · 보유 ${this.availableBridges})`);
        this.sfx.play('warn');
        return;
      }
      if (terrainCheck.tunnelCount > this.availableTunnels) {
        this.showToast(`터널이 부족합니다 (필요 ${terrainCheck.tunnelCount} · 보유 ${this.availableTunnels})`);
        this.sfx.play('warn');
        return;
      }

      // 스냅샷 기록
      this.undoStack.push(this.captureNetworkSnapshot());
      if (this.undoStack.length > 30) this.undoStack.shift();
      this.redoStack = [];

      if (plan.mode === 'CLOSE_LOOP') {
        plan.line.isCircular = true;
        plan.line.lastConnectedStationId = origTo.id;
        this.logEvent(`${plan.line.name} 순환선 개통 완료`);
        this.showToast(`${plan.line.name} 순환선 개통`);
      } else if (plan.mode === 'EXTEND') {
        const line = plan.line;
        const addSt = plan.stationToAdd;
        line.lastConnectedStationId = addSt.id;
        if (plan.isFront) {
          line.stationIds.unshift(addSt.id);
          for (const tr of this.trains) {
            if (tr.lineId === line.id) tr.currentStationIndex += 1;
          }
        } else {
          line.stationIds.push(addSt.id);
        }
        if (!addSt.connectedLineIds.includes(line.id)) {
          addSt.connectedLineIds.push(line.id);
        }
        this.activeLineSlot = line.slot;
        this.logEvent(`${line.name} 연장 — ${addSt.name} 합류 (총 ${line.stationIds.length}개 역)`);
      } else if (plan.mode === 'NEW_LINE') {
        const slot = plan.slot;
        const lineId = `line_${slot}`;
        const newLine = {
          id: lineId,
          slot,
          name: `${slot}호선`,
          color: this.getSlotColor(slot),
          stationIds: [origFrom.id, origTo.id],
          lastConnectedStationId: origTo.id,
          isCircular: false
        };

        if (!origFrom.connectedLineIds.includes(lineId)) origFrom.connectedLineIds.push(lineId);
        if (!origTo.connectedLineIds.includes(lineId)) origTo.connectedLineIds.push(lineId);
        this.lines.push(newLine);
        this.lines.sort((a, b) => a.slot - b.slot);

        // 순환선에서 분기 신설된 경우 활성 호선도 새 분기 호선으로 자연스럽게 전환
        this.activeLineSlot = slot;

        const existingTrainsOnLine = this.trains.filter(t => t.lineId === newLine.id).length;
        if (existingTrainsOnLine === 0 && (this.availableTrains > 0 || this.trains.length < this.lines.length)) {
          this.spawnTrainOnLine(newLine, true, false);
        }
        while (this.extraPendingTrains > 0) {
          this.extraPendingTrains--;
          this.spawnTrainOnLine(newLine, false, true);
        }

        if (plan.branchedFromCircular) {
          this.logEvent(`${plan.branchedFromCircular} 순환선 유지 — ${newLine.name} 분기 개통`);
          this.showToast(`${plan.branchedFromCircular} 유지 · ${newLine.name} 분기 개통`);
        } else {
          this.logEvent(`${newLine.name} 신규 개통 (${origFrom.name} - ${origTo.name})`);
        }
      }

      // 다리/터널 차감 및 지형 교차 마커 배치
      const segmentLineId = plan.mode === 'NEW_LINE' ? `line_${plan.slot}` : plan.line.id;
      const usedInfra = [];
      if (terrainCheck.bridgeCount > 0) {
        this.availableBridges -= terrainCheck.bridgeCount;
        for (const pos of terrainCheck.bridgePositions) {
          this.bridges.push({
            id: 'br_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6),
            pos,
            lineId: segmentLineId,
            segA: origFrom.id,
            segB: origTo.id
          });
        }
        usedInfra.push(`다리 ${terrainCheck.bridgeCount}개 사용 (잔여 ${this.availableBridges})`);
      }
      if (terrainCheck.tunnelCount > 0) {
        this.availableTunnels -= terrainCheck.tunnelCount;
        for (const pos of terrainCheck.tunnelPositions) {
          this.tunnels.push({
            id: 'tu_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6),
            pos,
            lineId: segmentLineId,
            segA: origFrom.id,
            segB: origTo.id
          });
        }
        usedInfra.push(`터널 ${terrainCheck.tunnelCount}개 사용 (잔여 ${this.availableTunnels})`);
      }
      if (usedInfra.length > 0) {
        const infraMsg = usedInfra.join(' · ');
        this.showToast(infraMsg);
        this.logEvent(`인프라 건설 — ${infraMsg}`);
      }

      this.rebuildCrossings();
      this.sfx.play('connect');
      this.updateHUD();
    }

    /**
     * 특정 호선 전체 철거 (다리·터널·열차 전액 회수, 실행 취소 U 지원)
     */
    deleteLine(slot = this.activeLineSlot) {
      const line = this.getLineBySlot(slot);
      if (!line) {
        this.showToast(`${slot}호선은 아직 개통되지 않았습니다.`);
        this.sfx.play('warn');
        return;
      }

      this.undoStack.push(this.captureNetworkSnapshot());
      if (this.undoStack.length > 30) this.undoStack.shift();
      this.redoStack = [];

      // 다리·터널 회수
      let refundedBridges = 0;
      let refundedTunnels = 0;
      this.bridges = this.bridges.filter(b => {
        if (b.lineId === line.id) {
          refundedBridges++;
          return false;
        }
        return true;
      });
      this.tunnels = this.tunnels.filter(t => {
        if (t.lineId === line.id) {
          refundedTunnels++;
          return false;
        }
        return true;
      });
      this.availableBridges += refundedBridges;
      this.availableTunnels += refundedTunnels;

      // 열차 회수 및 탑승 승객 안전 하차
      let refundedTrains = 0;
      this.trains = this.trains.filter(tr => {
        if (tr.lineId === line.id) {
          refundedTrains++;
          const stId = line.stationIds[Math.min(tr.currentStationIndex, line.stationIds.length - 1)];
          const dropSt = this.stations.find(s => s.id === stId);
          if (dropSt && tr.passengers && tr.passengers.length > 0) {
            const safeCap = Math.max(0, CONFIG.station.maxPassengers - 1);
            for (const p of tr.passengers) {
              if (dropSt.passengers.length < safeCap) {
                dropSt.passengers.push(p);
              }
            }
          }
          return false;
        }
        return true;
      });
      this.availableTrains += refundedTrains;

      // 역 연결 정보 해제
      for (const st of this.stations) {
        st.connectedLineIds = st.connectedLineIds.filter(id => id !== line.id);
      }

      this.lines = this.lines.filter(l => l.id !== line.id);
      if (this.connectingFromStation) {
        this.cancelConnecting();
      }

      this.rebuildCrossings();
      this.sfx.play('click');
      this.updateHUD();
      this.updateInspector();

      const refundParts = [];
      if (refundedTrains > 0) refundParts.push(`열차 +${refundedTrains}`);
      if (refundedBridges > 0) refundParts.push(`다리 +${refundedBridges}`);
      if (refundedTunnels > 0) refundParts.push(`터널 +${refundedTunnels}`);
      const refundText = refundParts.length > 0 ? ` (${refundParts.join(' · ')} 회수)` : '';
      this.showToast(`${line.name} 철거 완료${refundText} · U로 복구`);
      this.logEvent(`${line.name} 철거${refundText}`);
    }

    /**
     * 선택된 호선의 마지막 연결 구간 1칸만 끊기 (순환선 열기 포함)
     */
    trimLineLastSegment(slot = this.activeLineSlot) {
      const line = this.getLineBySlot(slot);
      if (!line) {
        this.showToast(`${slot}호선은 아직 개통되지 않았습니다.`);
        this.sfx.play('warn');
        return;
      }

      if (!line.isCircular && line.stationIds.length <= 2) {
        this.deleteLine(slot);
        return;
      }

      this.undoStack.push(this.captureNetworkSnapshot());
      if (this.undoStack.length > 30) this.undoStack.shift();
      this.redoStack = [];

      const matchesSegment = (item, idA, idB) =>
        item.lineId === line.id &&
        ((item.segA === idA && item.segB === idB) || (item.segA === idB && item.segB === idA));

      let segA = null;
      let segB = null;
      let actionDesc = '';

      if (line.isCircular) {
        segA = line.stationIds[0];
        segB = line.stationIds[line.stationIds.length - 1];
        line.isCircular = false;
        line.lastConnectedStationId = segB;
        for (const tr of this.trains) {
          if (tr.lineId !== line.id) continue;
          if (tr.currentStationIndex >= line.stationIds.length - 1 && tr.direction === 1) {
            tr.currentStationIndex = line.stationIds.length - 1;
            tr.direction = -1;
            tr.progress = 0;
          } else if (tr.currentStationIndex === 0 && tr.direction === -1) {
            tr.direction = 1;
            tr.progress = 0;
          }
        }
        actionDesc = `${line.name} 순환 구간 해제 (일반 노선 전환)`;
      } else {
        const trimFromFront = line.lastConnectedStationId === line.stationIds[0];
        let removedId;
        let neighborId;
        if (trimFromFront) {
          removedId = line.stationIds.shift();
          neighborId = line.stationIds[0];
          for (const tr of this.trains) {
            if (tr.lineId !== line.id) continue;
            tr.currentStationIndex = Math.max(0, tr.currentStationIndex - 1);
            if (tr.currentStationIndex === 0 && tr.direction === -1) {
              tr.direction = 1;
              tr.progress = 0;
            }
          }
        } else {
          removedId = line.stationIds.pop();
          neighborId = line.stationIds[line.stationIds.length - 1];
          for (const tr of this.trains) {
            if (tr.lineId !== line.id) continue;
            if (tr.currentStationIndex >= line.stationIds.length - 1) {
              tr.currentStationIndex = line.stationIds.length - 1;
              tr.direction = -1;
              tr.progress = 0;
            }
          }
        }
        segA = removedId;
        segB = neighborId;
        line.lastConnectedStationId = neighborId;

        const removedSt = this.stations.find(s => s.id === removedId);
        if (removedSt) {
          removedSt.connectedLineIds = removedSt.connectedLineIds.filter(id => id !== line.id);
        }
        actionDesc = `${line.name} 끝 구간 해제 (${removedSt ? removedSt.name : '역'} 분리)`;
      }

      let refundedBridges = 0;
      let refundedTunnels = 0;
      if (segA && segB) {
        this.bridges = this.bridges.filter(b => {
          if (matchesSegment(b, segA, segB)) {
            refundedBridges++;
            return false;
          }
          return true;
        });
        this.tunnels = this.tunnels.filter(t => {
          if (matchesSegment(t, segA, segB)) {
            refundedTunnels++;
            return false;
          }
          return true;
        });
        this.availableBridges += refundedBridges;
        this.availableTunnels += refundedTunnels;
      }

      this.rebuildCrossings();
      this.sfx.play('click');
      this.updateHUD();
      this.updateInspector();

      const refundParts = [];
      if (refundedBridges > 0) refundParts.push(`다리 +${refundedBridges}`);
      if (refundedTunnels > 0) refundParts.push(`터널 +${refundedTunnels}`);
      const refundText = refundParts.length > 0 ? ` (${refundParts.join(' · ')} 회수)` : '';
      this.showToast(`${actionDesc}${refundText}`);
      this.logEvent(`${actionDesc}${refundText}`);
    }

    showDeleteModeBanner() {
      const banner = document.getElementById('connectingBanner');
      const text = document.getElementById('connectingBannerText');
      const dot = document.getElementById('connectingBannerDot');
      if (!banner || !text) return;

      if (dot) dot.style.backgroundColor = '#C92A2A';
      text.textContent = '노선 삭제 모드 — 삭제할 노선 구간을 클릭하세요 (중간 구간 클릭 시 종점 방향까지 일괄 삭제) · X/우클릭/ESC 종료';
      banner.classList.remove('hidden');
    }

    setDeleteMode(enabled, notify = true) {
      const next = Boolean(enabled);
      if (this.isDeleteMode === next) return;
      this.isDeleteMode = next;
      this.hoveredDeleteSegment = null;

      const btnDel = document.getElementById('btnToolDeleteLine');
      const btnLine = document.getElementById('btnToolLine');
      if (btnDel) btnDel.classList.toggle('active', next);
      if (btnLine) btnLine.classList.toggle('active', !next);

      if (next) {
        if (this.connectingFromStation) {
          this.connectingFromStation = null;
        }
        this.hoveredDeleteSegment = this.findLineSegmentAt(this.mouseWorldPos);
        this.showDeleteModeBanner();
        if (notify) {
          this.sfx.play('click');
          this.showToast('노선 삭제 모드 켜짐 — 없앨 노선 구간을 클릭하세요 (X/우클릭/ESC 종료)');
        }
      } else {
        const banner = document.getElementById('connectingBanner');
        if (banner && !this.connectingFromStation) {
          banner.classList.add('hidden');
        }
        if (notify) {
          this.sfx.play('click');
          this.showToast('노선 삭제 모드 종료');
        }
      }
    }

    toggleDeleteMode() {
      this.setDeleteMode(!this.isDeleteMode, true);
    }

    /**
     * 평행 오프셋이 반영된 모든 노선 구간의 실제 렌더링 좌표 목록 반환
     */
    getRenderedLineSegments() {
      const pairCounts = new Map();
      const pairSeen = new Map();
      const makePairKey = (a, b) => (a < b ? `${a}|${b}` : `${b}|${a}`);

      for (const line of this.lines) {
        for (const [u, v] of this.getLineSegments(line)) {
          const key = makePairKey(u, v);
          pairCounts.set(key, (pairCounts.get(key) || 0) + 1);
        }
      }

      const rendered = [];
      for (const line of this.lines) {
        const segs = this.getLineSegments(line);
        for (let segIdx = 0; segIdx < segs.length; segIdx++) {
          const [u, v] = segs[segIdx];
          const stU = this.stations.find(s => s.id === u);
          const stV = this.stations.find(s => s.id === v);
          if (!stU || !stV) continue;

          const key = makePairKey(u, v);
          const total = pairCounts.get(key) || 1;
          const idx = pairSeen.get(key) || 0;
          pairSeen.set(key, idx + 1);

          let ox = 0;
          let oy = 0;
          if (total > 1) {
            const refA = u < v ? stU.position : stV.position;
            const refB = u < v ? stV.position : stU.position;
            const dx = refB.x - refA.x;
            const dy = refB.y - refA.y;
            const len = Math.max(1, Math.hypot(dx, dy));
            const shift = (idx - (total - 1) * 0.5) * 6.5;
            ox = (-dy / len) * shift;
            oy = (dx / len) * shift;
          }

          rendered.push({
            line,
            segIdx,
            u,
            v,
            stU,
            stV,
            ox,
            oy,
            p1: { x: stU.position.x + ox, y: stU.position.y + oy },
            p2: { x: stV.position.x + ox, y: stV.position.y + oy }
          });
        }
      }
      return rendered;
    }

    /**
     * 마우스 월드 좌표에서 가장 가까운 노선 구간 탐색
     */
    findLineSegmentAt(worldPos) {
      if (!worldPos || this.lines.length === 0) return null;
      const threshold = Math.max(12, 14 / Math.max(0.4, this.camera.zoom));
      let best = null;
      let bestDist = threshold;

      for (const seg of this.getRenderedLineSegments()) {
        const { dist, proj } = Geometry.pointToSegmentDist(worldPos, seg.p1, seg.p2);
        if (dist <= bestDist) {
          bestDist = dist;
          best = { ...seg, dist, proj };
        }
      }
      return best;
    }

    /**
     * 특정 구간(segIdx)을 클릭했을 때 삭제될 구간·역·잔여 노선 계산
     * - 종점으로 가는 마지막 구간이면 그 구간 1개만 삭제
     * - 종점으로 가는 구간이 아니면 해당 구간부터 종점 방향의 앞 구간들까지 일괄 삭제
     * - 순환선이면 클릭한 해당 구간 1개만 끊어 일반 노선으로 전환
     */
    computeSegmentDeletionPlan(line, segIdx) {
      if (!line || !line.stationIds || line.stationIds.length < 2) return null;
      const segs = this.getLineSegments(line);
      if (segIdx < 0 || segIdx >= segs.length) return null;

      const len = line.stationIds.length;

      // 1. 순환선: 클릭한 구간 1개만 해제하여 연속된 일반 노선으로 변환
      if (line.isCircular && len >= 3) {
        const startIdx = (segIdx + 1) % len;
        const remainingStationIds = [];
        for (let i = 0; i < len; i++) {
          remainingStationIds.push(line.stationIds[(startIdx + i) % len]);
        }
        return {
          line,
          segIdx,
          opensLoop: true,
          deletesWholeLine: false,
          affectedSegIndices: [segIdx],
          removedPairs: [segs[segIdx]],
          remainingStationIds,
          removedStationIds: [],
          newLastConnectedStationId: remainingStationIds[remainingStationIds.length - 1]
        };
      }

      // 2. 일반 노선: 종점 방향을 판정하여 클릭한 구간 ~ 종점까지 삭제
      const terminusAtFront = line.lastConnectedStationId === line.stationIds[0];
      let affectedSegIndices = [];
      let remainingStationIds = [];
      let removedStationIds = [];
      let newLastConnectedStationId = null;

      if (!terminusAtFront) {
        // 시점(0) → 종점(len - 1): segIdx부터 len - 2까지 삭제
        for (let i = segIdx; i < segs.length; i++) {
          affectedSegIndices.push(i);
        }
        remainingStationIds = line.stationIds.slice(0, segIdx + 1);
        removedStationIds = line.stationIds.slice(segIdx + 1);
        newLastConnectedStationId = remainingStationIds.length > 0
          ? remainingStationIds[remainingStationIds.length - 1]
          : null;
      } else {
        // 종점(0) ← 시점(len - 1): 0부터 segIdx까지 삭제
        for (let i = 0; i <= segIdx; i++) {
          affectedSegIndices.push(i);
        }
        remainingStationIds = line.stationIds.slice(segIdx + 1);
        removedStationIds = line.stationIds.slice(0, segIdx + 1);
        newLastConnectedStationId = remainingStationIds.length > 0
          ? remainingStationIds[0]
          : null;
      }

      const deletesWholeLine = remainingStationIds.length < 2;
      const removedPairs = affectedSegIndices.map(i => segs[i]);

      return {
        line,
        segIdx,
        opensLoop: false,
        deletesWholeLine,
        affectedSegIndices,
        removedPairs,
        remainingStationIds,
        removedStationIds: deletesWholeLine ? [...line.stationIds] : removedStationIds,
        newLastConnectedStationId
      };
    }

    /**
     * 삭제 모드에서 클릭한 노선 구간 삭제 (종점 방향 앞 구간 포함)
     */
    deleteLineFromSegment(hit) {
      if (!hit || !hit.line) return;
      const plan = this.computeSegmentDeletionPlan(hit.line, hit.segIdx);
      if (!plan) return;

      const targetLine = plan.line;

      // 남는 역이 2개 미만이면 노선 전체 철거
      if (plan.deletesWholeLine) {
        this.hoveredDeleteSegment = null;
        this.deleteLine(targetLine.slot);
        return;
      }

      this.undoStack.push(this.captureNetworkSnapshot());
      if (this.undoStack.length > 30) this.undoStack.shift();
      this.redoStack = [];

      const oldStationIds = [...targetLine.stationIds];
      const wasCircular = targetLine.isCircular;
      const removedPairSet = new Set(
        plan.removedPairs.map(([a, b]) => (a < b ? `${a}|${b}` : `${b}|${a}`))
      );
      const matchesRemovedSegment = (item) => {
        if (item.lineId !== targetLine.id) return false;
        const key = item.segA < item.segB ? `${item.segA}|${item.segB}` : `${item.segB}|${item.segA}`;
        return removedPairSet.has(key);
      };

      // 삭제된 모든 구간의 다리·터널 회수
      let refundedBridges = 0;
      let refundedTunnels = 0;
      this.bridges = this.bridges.filter(b => {
        if (matchesRemovedSegment(b)) {
          refundedBridges++;
          return false;
        }
        return true;
      });
      this.tunnels = this.tunnels.filter(t => {
        if (matchesRemovedSegment(t)) {
          refundedTunnels++;
          return false;
        }
        return true;
      });
      this.availableBridges += refundedBridges;
      this.availableTunnels += refundedTunnels;

      // 노선 상태 갱신
      targetLine.stationIds = plan.remainingStationIds;
      targetLine.isCircular = false;
      targetLine.lastConnectedStationId = plan.newLastConnectedStationId;

      // 분리된 역의 연결 노선 목록 정리
      for (const stId of plan.removedStationIds) {
        const st = this.stations.find(s => s.id === stId);
        if (st) {
          st.connectedLineIds = st.connectedLineIds.filter(id => id !== targetLine.id);
        }
      }

      // 열차 위치 및 진행 방향 안전 보정
      const newLen = targetLine.stationIds.length;
      const fallbackIdx = Math.max(0, targetLine.stationIds.indexOf(targetLine.lastConnectedStationId));
      for (const tr of this.trains) {
        if (tr.lineId !== targetLine.id) continue;
        const oldIdx = Math.max(0, Math.min(tr.currentStationIndex, oldStationIds.length - 1));
        const curStId = oldStationIds[oldIdx];
        const nextOldIdx = wasCircular
          ? (oldIdx + tr.direction + oldStationIds.length) % oldStationIds.length
          : oldIdx + tr.direction;
        const nextStId = (nextOldIdx >= 0 && nextOldIdx < oldStationIds.length)
          ? oldStationIds[nextOldIdx]
          : null;
        const movingOnRemovedSeg = nextStId
          ? removedPairSet.has(curStId < nextStId ? `${curStId}|${nextStId}` : `${nextStId}|${curStId}`)
          : false;

        const mappedIdx = targetLine.stationIds.indexOf(curStId);
        if (mappedIdx !== -1) {
          tr.currentStationIndex = mappedIdx;
          if (movingOnRemovedSeg) {
            tr.progress = 0;
          }
          if (tr.currentStationIndex >= newLen - 1 && tr.direction === 1) {
            tr.direction = -1;
            tr.progress = 0;
          } else if (tr.currentStationIndex <= 0 && tr.direction === -1) {
            tr.direction = 1;
            tr.progress = 0;
          }
        } else {
          tr.currentStationIndex = fallbackIdx;
          tr.progress = 0;
          tr.direction = fallbackIdx >= newLen - 1 ? -1 : 1;
        }
      }

      this.hoveredDeleteSegment = this.findLineSegmentAt(this.mouseWorldPos);
      this.rebuildCrossings();
      this.sfx.play('click');
      this.updateHUD();
      this.updateInspector();

      const refundParts = [];
      if (refundedBridges > 0) refundParts.push(`다리 +${refundedBridges}`);
      if (refundedTunnels > 0) refundParts.push(`터널 +${refundedTunnels}`);
      const refundText = refundParts.length > 0 ? ` (${refundParts.join(' · ')} 회수)` : '';

      let desc;
      if (plan.opensLoop) {
        desc = `${targetLine.name} 순환 구간 해제`;
      } else if (plan.affectedSegIndices.length === 1) {
        desc = `${targetLine.name} 종점 구간 삭제`;
      } else {
        desc = `${targetLine.name} 구간 ${plan.affectedSegIndices.length}개 일괄 삭제 (종점 방향 포함)`;
      }

      this.showToast(`${desc}${refundText} · U로 복구`);
      this.logEvent(`${desc}${refundText}`);
    }

    spawnTrainOnLine(line, consumeInventory = true, startOffset = false) {
      if (line.stationIds.length < 2) return null;
      if (consumeInventory && this.availableTrains > 0) {
        this.availableTrains--;
      }

      const existingCount = this.trains.filter(t => t.lineId === line.id).length;
      let startIdx = 0;
      let startDir = 1;
      let startProg = 0;

      if (startOffset && existingCount > 0) {
        if (line.stationIds.length >= 3) {
          startIdx = Math.floor(line.stationIds.length / 2) % line.stationIds.length;
          startDir = (existingCount % 2 === 1 && !line.isCircular) ? -1 : 1;
        } else {
          startIdx = line.stationIds.length - 1;
          startDir = -1;
          startProg = existingCount > 1 ? 0.5 : 0;
        }
      }

      const train = {
        id: `train_${Date.now()}_${Math.random().toString(36).slice(2, 5)}`,
        lineId: line.id,
        currentStationIndex: startIdx,
        direction: startDir,
        progress: startProg,
        passengers: [],
        state: 'MOVING',
        stopTimer: 0
      };
      this.trains.push(train);
      return train;
    }

    checkSegmentTerrain(p1, p2) {
      let bridgeCount = 0;
      let tunnelCount = 0;
      const bridgePositions = [];
      const tunnelPositions = [];

      for (const t of this.terrains) {
        if (Geometry.segmentIntersectsPolygon(p1, p2, t.polygon)) {
          const crossPos = Geometry.segmentPolygonCenter(p1, p2, t.polygon);
          if (t.type === 'RIVER') {
            bridgeCount++;
            bridgePositions.push(crossPos);
          } else if (t.type === 'MOUNTAIN') {
            tunnelCount++;
            tunnelPositions.push(crossPos);
          }
        }
      }

      return {
        needsBridge: bridgeCount > 0,
        needsTunnel: tunnelCount > 0,
        bridgeCount,
        tunnelCount,
        bridgePositions,
        tunnelPositions
      };
    }

    getLineSegments(line) {
      const segs = [];
      const ids = line.stationIds;
      for (let i = 0; i < ids.length - 1; i++) {
        segs.push([ids[i], ids[i + 1]]);
      }
      if (line.isCircular && ids.length >= 3) {
        segs.push([ids[ids.length - 1], ids[0]]);
      }
      return segs;
    }

    rebuildCrossings() {
      this.crossingPoints = [];
      const stationMap = new Map(this.stations.map(s => [s.id, s]));

      for (let i = 0; i < this.lines.length; i++) {
        const segsA = this.getLineSegments(this.lines[i]);
        for (let j = i + 1; j < this.lines.length; j++) {
          const segsB = this.getLineSegments(this.lines[j]);
          for (const [a1, a2] of segsA) {
            for (const [b1, b2] of segsB) {
              if (a1 === b1 || a1 === b2 || a2 === b1 || a2 === b2) continue;
              const sA1 = stationMap.get(a1), sA2 = stationMap.get(a2);
              const sB1 = stationMap.get(b1), sB2 = stationMap.get(b2);
              if (!sA1 || !sA2 || !sB1 || !sB2) continue;
              const hit = Geometry.segmentIntersectionPoint(sA1.position, sA2.position, sB1.position, sB2.position);
              if (hit) this.crossingPoints.push(hit);
            }
          }
        }
      }
    }

    // ==========================================================================
    // 6. 환승 경로 탐색 (순환선 ↔ 분기선 다중 환승 BFS)
    // ==========================================================================
    isPassengerDestination(station, passenger) {
      if (passenger.targetId && station.id === passenger.targetId) return true;
      if (station.shape === passenger.targetShape && station.color === passenger.targetColor) return true;
      const exactExists = this.stations.some(
        s => s.id !== passenger.sourceId && s.shape === passenger.targetShape && s.color === passenger.targetColor
      );
      if (!exactExists && station.shape === passenger.targetShape) return true;
      return false;
    }

    /**
     * 각 역에서 승객 목적지까지 필요한 최소 탑승 노선 수(환승 횟수 + 1)를 계산한다.
     * 목적지 역 자체는 0, 직통 연결 역은 1, 1회 환승 역은 2 ...
     */
    computeRideDistances(passenger) {
      const dist = {};
      const queue = [];

      for (const st of this.stations) {
        if (this.isPassengerDestination(st, passenger)) {
          dist[st.id] = 0;
          queue.push(st.id);
        } else {
          dist[st.id] = Infinity;
        }
      }

      let head = 0;
      const visitedLines = new Set();

      while (head < queue.length) {
        const curStationId = queue[head++];
        const curDist = dist[curStationId];

        for (const line of this.lines) {
          if (visitedLines.has(line.id) || line.stationIds.length < 2) continue;
          if (!line.stationIds.includes(curStationId)) continue;

          visitedLines.add(line.id);
          for (const neighborId of line.stationIds) {
            if (dist[neighborId] > curDist + 1) {
              dist[neighborId] = curDist + 1;
              queue.push(neighborId);
            }
          }
        }
      }

      return dist;
    }

    getMinRideDistOnLine(line, rideDist) {
      let best = Infinity;
      for (const stId of line.stationIds) {
        const d = rideDist[stId];
        if (d !== undefined && d < best) best = d;
      }
      return best;
    }

    // ==========================================================================
    // 7. 시뮬레이션 루프 (1일=60초, 24h 즉시 날짜 변경, 2일 보급, 주간 1/6 확장)
    // ==========================================================================
    update(dt) {
      if (this.isPaused || this.isGameOver || this.isRewardModalOpen) return;

      const gameDelta = dt * this.speed;
      this.simTime += gameDelta * (86400 / CONFIG.simulation.dayDurationRealSec);

      this.tickDayRollover();
      this.tickPassengerSpawner(gameDelta);
      this.tickTrains(gameDelta);
      this.tickCongestion(gameDelta);
      if (this.isGameOver) {
        this.updateHUD();
        return;
      }
      this.tickInfraSupply();
      this.tickStationSpawn();
      this.tickWeeklyCycle();

      this.updateHUD();
    }

    tickDayRollover() {
      const currentDay = this.getCurrentDay();
      if (currentDay > this.lastRecordedDay) {
        this.lastRecordedDay = currentDay;
        const timeEl = document.getElementById('timeDisplay');
        if (timeEl) {
          const totalSec = Math.floor(((this.simTime % 86400) + 86400) % 86400);
          const hours = String(Math.floor(totalSec / 3600)).padStart(2, '0');
          const mins = String(Math.floor((totalSec % 3600) / 60)).padStart(2, '0');
          timeEl.textContent = `Day ${currentDay} · ${hours}:${mins}`;
        }
        this.logEvent(`Day ${currentDay} 시작 (24시간 경과)`);
      }
    }

    tickPassengerSpawner(dt) {
      const currentHour = (this.simTime / 3600) % 24;
      let rate = 0.85;

      const isMorningRush = currentHour >= 7 && currentHour < 10;
      const isEveningRush = currentHour >= 17 && currentHour < 20;
      const isRush = isMorningRush || isEveningRush;

      if (isRush) rate = 1.85;
      else if (currentHour >= 23 || currentHour < 5) rate = 0.35;

      const rushBadge = document.getElementById('rushBadge');
      if (rushBadge) {
        rushBadge.classList.toggle('hidden', !isRush);
        rushBadge.textContent = isMorningRush ? '출근 러시' : '퇴근 러시';
      }

      for (const station of this.stations) {
        if (station.passengers.length >= CONFIG.station.maxPassengers) continue;
        if (Math.random() < 0.075 * rate * dt) {
          const targetStation = this.pickTargetStation(station);
          if (targetStation) {
            station.passengers.push({
              id: 'p_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6),
              sourceId: station.id,
              targetId: targetStation.id,
              targetShape: targetStation.shape,
              targetColor: targetStation.color
            });
          }
        }
      }
    }

    pickTargetStation(sourceStation) {
      const others = this.stations.filter(s => s.id !== sourceStation.id);
      if (others.length === 0) return null;

      // D-02: 모양 후보 추출 -> 색상 우선 -> 최단거리 선택
      const randomRef = others[Math.floor(Math.random() * others.length)];
      const sameShape = others.filter(s => s.shape === randomRef.shape);
      const sameColor = sameShape.filter(s => s.color === randomRef.color);
      const pool = sameColor.length > 0 ? sameColor : sameShape;

      let best = pool[0];
      let bestDist = Geometry.dist(sourceStation.position, best.position);
      for (let i = 1; i < pool.length; i++) {
        const d = Geometry.dist(sourceStation.position, pool[i].position);
        if (d < bestDist) {
          bestDist = d;
          best = pool[i];
        }
      }
      return best;
    }

    getTrainWorldPosition(train, line) {
      const stA = this.stations.find(s => s.id === line.stationIds[train.currentStationIndex]);
      if (!stA) return null;
      if (train.state === 'STOPPED') {
        const sameStop = this.trains.filter(
          t => t.state === 'STOPPED' && t.lineId === train.lineId && t.currentStationIndex === train.currentStationIndex
        );
        let shiftX = 0;
        if (sameStop.length > 1) {
          const idx = sameStop.indexOf(train);
          shiftX = (idx - (sameStop.length - 1) * 0.5) * 32;
        }
        return { x: stA.position.x + shiftX, y: stA.position.y - 30 };
      }
      let nextIndex = train.currentStationIndex + train.direction;
      if (line.isCircular) {
        nextIndex = (nextIndex + line.stationIds.length) % line.stationIds.length;
      } else {
        nextIndex = Math.max(0, Math.min(line.stationIds.length - 1, nextIndex));
      }
      const stB = this.stations.find(s => s.id === line.stationIds[nextIndex]);
      if (!stB) return { x: stA.position.x, y: stA.position.y };
      return {
        x: stA.position.x + (stB.position.x - stA.position.x) * train.progress,
        y: stA.position.y + (stB.position.y - stA.position.y) * train.progress
      };
    }

    isNearCrossing(pos) {
      for (const cp of this.crossingPoints) {
        if (Geometry.dist(pos, cp) <= CONFIG.train.crossingRadius) return true;
      }
      return false;
    }

    tickTrains(dt) {
      for (const train of this.trains) {
        const line = this.lines.find(l => l.id === train.lineId);
        if (!line || line.stationIds.length < 2) continue;

        if (train.state === 'STOPPED') {
          train.stopTimer -= dt;
          if (train.stopTimer <= 0) {
            train.state = 'MOVING';
          }
          continue;
        }

        const fromId = line.stationIds[train.currentStationIndex];
        let nextIndex = train.currentStationIndex + train.direction;

        if (line.isCircular) {
          nextIndex = (nextIndex + line.stationIds.length) % line.stationIds.length;
        } else {
          if (nextIndex >= line.stationIds.length) {
            train.direction = -1;
            nextIndex = line.stationIds.length - 2;
          } else if (nextIndex < 0) {
            train.direction = 1;
            nextIndex = 1;
          }
        }

        const stA = this.stations.find(s => s.id === fromId);
        const stB = this.stations.find(s => s.id === line.stationIds[nextIndex]);
        if (!stA || !stB) continue;

        const curPos = {
          x: stA.position.x + (stB.position.x - stA.position.x) * train.progress,
          y: stA.position.y + (stB.position.y - stA.position.y) * train.progress
        };
        const speedMult = this.isNearCrossing(curPos) ? CONFIG.train.crossingSpeedMultiplier : 1.0;

        const dist = Geometry.dist(stA.position, stB.position);
        const step = (CONFIG.train.baseSpeed * speedMult * dt) / Math.max(dist, 1);
        train.progress += step;

        if (train.progress >= 1.0) {
          train.progress = 0;
          train.currentStationIndex = nextIndex;
          train.state = 'STOPPED';
          train.stopTimer = CONFIG.train.stopDuration;
          this.handleStationStop(train, stB, line);
        }
      }
    }

    handleStationStop(train, station, line) {
      // 정차 사이클: 1. 최종 도착 하차 -> 2. 환승 하차 -> 3. 대기 승객 탑승
      let arrivedCount = 0;
      const stayingOnTrain = [];
      const transferAlighting = [];

      for (const p of train.passengers) {
        const rideDist = this.computeRideDistances(p);
        const dHere = rideDist[station.id];

        if (dHere === 0) {
          arrivedCount++;
        } else {
          const minOnCurrentLine = this.getMinRideDistOnLine(line, rideDist);
          if (dHere !== undefined && dHere <= minOnCurrentLine && dHere < Infinity) {
            transferAlighting.push(p);
          } else {
            stayingOnTrain.push(p);
          }
        }
      }

      train.passengers = stayingOnTrain;

      if (arrivedCount > 0) {
        this.totalArrivedPassengers += arrivedCount;
        const survivedDays = Math.floor((this.simTime - this.startSimTime) / 86400);
        this.score += arrivedCount * 10 + (survivedDays > 0 ? 1 : 0);
        this.sfx.play('arrive');
      }

      // 환승 승객 플랫폼 이동 (게임오버 방지를 위해 정원 여유분 내에서 우선 수용)
      for (const tp of transferAlighting) {
        if (station.passengers.length < CONFIG.station.maxPassengers - 1) {
          station.passengers.push(tp);
        } else {
          train.passengers.push(tp);
        }
      }

      // 대기 승객 탑승 (열차당 고정 최대 정원 = 15명)
      const capacity = this.getTrainMaxCapacity();
      const availableSeats = Math.max(0, capacity - train.passengers.length);

      if (availableSeats > 0 && station.passengers.length > 0) {
        const boarding = [];
        const keepWaiting = [];

        for (const p of station.passengers) {
          if (boarding.length < availableSeats) {
            const rideDist = this.computeRideDistances(p);
            const dHere = rideDist[station.id];
            const minOnLine = this.getMinRideDistOnLine(line, rideDist);
            if (dHere < Infinity && minOnLine < dHere) {
              boarding.push(p);
              continue;
            }
          }
          keepWaiting.push(p);
        }

        train.passengers.push(...boarding);
        station.passengers = keepWaiting;
      }
    }

    getStationWarningStage(count) {
      if (count >= CONFIG.station.warn3Threshold) return 3;
      if (count >= CONFIG.station.warn2Threshold) return 2;
      if (count >= CONFIG.station.warn1Threshold) return 1;
      return 0;
    }

    tickCongestion(dt = 0) {
      const graceSec = CONFIG.station.overflowGraceSec || 1.0;

      for (const station of this.stations) {
        const count = station.passengers.length;
        if (count >= CONFIG.station.maxPassengers) {
          const prevTimer = station.overflowTimer || 0;
          if (prevTimer === 0) {
            this.logEvent(`[유예 시작] ${station.name} 대기 ${count}명 도달 — ${graceSec}초 내 해소 필요`);
            this.sfx.play('warn3');
          }
          station.overflowTimer = prevTimer + dt;
          if (station.overflowTimer >= graceSec) {
            this.triggerGameOver(station);
            return;
          }
        } else {
          station.overflowTimer = 0;
        }
      }

      for (const station of this.stations) {
        const count = station.passengers.length;
        const stage = this.getStationWarningStage(count);
        const prevStage = station.warningStage || 0;

        if (stage > prevStage) {
          if (stage === 1) {
            this.logEvent(`[1차 경고] ${station.name} 대기 인원 ${count}/${CONFIG.station.maxPassengers}명 도달`);
            this.showToast(`1차 경고: ${station.name} 대기 ${count}명 (한도 ${CONFIG.station.maxPassengers}명)`, 'warn-1');
            this.sfx.play('warn1');
          } else if (stage === 2) {
            this.logEvent(`[2차 경고] ${station.name} 대기 인원 ${count}/${CONFIG.station.maxPassengers}명 — 혼잡 심화`);
            this.showToast(`2차 경고: ${station.name} 대기 ${count}명 (한도 ${CONFIG.station.maxPassengers}명)`, 'warn-2');
            this.sfx.play('warn2');
          } else if (stage === 3) {
            this.logEvent(`[3차 경고] ${station.name} 대기 인원 ${count}/${CONFIG.station.maxPassengers}명 — 운행 중단 임박`);
            this.showToast(`3차 경고: ${station.name} 대기 ${count}명 — ${CONFIG.station.maxPassengers}명 도달 시 게임오버`, 'warn-3');
            this.sfx.play('warn3');
          }
        }
        station.warningStage = stage;
      }

      this.updateWarningBanner();
    }

    updateWarningBanner() {
      const banner = document.getElementById('warningBanner');
      const tag = document.getElementById('warningStageTag');
      const text = document.getElementById('warningBannerText');
      if (!banner || !tag || !text) return;

      if (this.isGameOver) {
        banner.classList.add('hidden');
        return;
      }

      let criticalStation = null;
      let maxStage = 0;

      for (const st of this.stations) {
        const stage = this.getStationWarningStage(st.passengers.length);
        if (stage > maxStage ||
            (stage > 0 && stage === maxStage && criticalStation && st.passengers.length > criticalStation.passengers.length)) {
          maxStage = stage;
          criticalStation = st;
        }
      }

      if (maxStage === 0 || !criticalStation) {
        banner.classList.add('hidden');
        return;
      }

      banner.classList.remove('hidden', 'warn-tier-1', 'warn-tier-2', 'warn-tier-3');
      banner.classList.add(`warn-tier-${maxStage}`);

      const count = criticalStation.passengers.length;
      if (count >= CONFIG.station.maxPassengers && (criticalStation.overflowTimer || 0) > 0) {
        const graceSec = CONFIG.station.overflowGraceSec || 1.0;
        const remain = Math.max(0, graceSec - criticalStation.overflowTimer);
        tag.textContent = '유예 중';
        text.textContent = `${criticalStation.name} 대기 ${count}/${CONFIG.station.maxPassengers}명 · ${remain.toFixed(1)}초 후 게임오버!`;
        return;
      }

      tag.textContent = `${maxStage}차 경고`;
      const suffix = maxStage === 3
        ? `한도 ${CONFIG.station.maxPassengers}명 임박 — 즉시 노선·열차 확충 필요`
        : (maxStage === 2 ? `혼잡 심화 (한도 ${CONFIG.station.maxPassengers}명)` : `대기 인원 증가 (한도 ${CONFIG.station.maxPassengers}명)`);
      text.textContent = `${criticalStation.name} 대기 ${count}/${CONFIG.station.maxPassengers}명 · ${suffix}`;
    }

    tickInfraSupply() {
      const elapsedSec = Math.max(0, this.simTime - this.startSimTime);
      const bridgeCycle = Math.floor(elapsedSec / (CONFIG.simulation.bridgeSupplyDays * 86400));
      const tunnelCycle = Math.floor(elapsedSec / (CONFIG.simulation.tunnelSupplyDays * 86400));

      let gainedBridges = 0;
      let gainedTunnels = 0;

      while (this.lastBridgeSupplyCycle < bridgeCycle) {
        this.lastBridgeSupplyCycle++;
        this.availableBridges += 1;
        gainedBridges += 1;
      }

      while (this.lastTunnelSupplyCycle < tunnelCycle) {
        this.lastTunnelSupplyCycle++;
        this.availableTunnels += 1;
        gainedTunnels += 1;
      }

      if (gainedBridges > 0 || gainedTunnels > 0) {
        const parts = [];
        if (gainedBridges > 0) parts.push(`다리 +${gainedBridges}`);
        if (gainedTunnels > 0) parts.push(`터널 +${gainedTunnels}`);
        const summary = parts.join(' · ');
        this.logEvent(`정기 보급 — ${summary} 지급 (다리 ${this.availableBridges} · 터널 ${this.availableTunnels})`);
        this.showToast(`정기 보급: ${summary}`);
        this.sfx.play('connect');
      }
    }

    tickStationSpawn() {
      const elapsedSec = Math.max(0, this.simTime - this.startSimTime);

      const baseCycle = Math.floor(elapsedSec / (CONFIG.simulation.stationBaseSpawnHours * 3600));
      while (this.lastBaseSpawnCycle < baseCycle) {
        this.lastBaseSpawnCycle++;
        if (this.stations.length < CONFIG.simulation.maxNaturalStations) {
          this.spawnNewStation('정규 개통');
        }
      }

      const bonusCycle = Math.floor(elapsedSec / (CONFIG.simulation.stationBonusCheckHours * 3600));
      while (this.lastBonusSpawnCycle < bonusCycle) {
        this.lastBonusSpawnCycle++;
        if (Math.random() < CONFIG.simulation.stationBonusChance &&
            this.stations.length < CONFIG.simulation.maxNaturalStations) {
          this.spawnNewStation('추가 개통');
        }
      }
    }

    tickWeeklyCycle() {
      const currentDay = this.getCurrentDay();
      if (currentDay <= 0) return;
      const currentWeek = Math.floor(currentDay / CONFIG.simulation.mapExpansionDays);

      if (currentWeek > this.playArea.expansionWeek) {
        this.playArea.expansionWeek = currentWeek;
        const factor = Math.pow(1 + CONFIG.simulation.mapExpansionRate, currentWeek);
        this.playArea.width = Math.round(CONFIG.playArea.width * factor);
        this.playArea.height = Math.round(CONFIG.playArea.height * factor);
        this.score += 50;

        // 확장된 맵에 맞춰 강 연장 및 산 1~2개 추가
        this.extendRiverToMapEdge();
        this.spawnExpansionMountains();

        this.logEvent(`제 ${currentWeek}주차 도시 1/6 확장 — 주간 보급을 선택하세요`);
        this.openWeeklyRewardModal(currentWeek);
      }
    }

    /**
     * 맵 확장 시 기존 강(river_0)을 현재 맵 너비 끝까지 부드럽게 연장한다.
     */
    extendRiverToMapEdge() {
      const river = this.terrains.find(t => t.id === 'river_0');
      if (!river || !river.polygon || river.polygon.length < 4) return;

      const area = this.playArea;
      const mapRight = area.centerX + area.width * 0.5;
      const mapLeft = area.centerX - area.width * 0.5;
      const riverWidth = 55;
      const stepDist = 80;

      // 폴리곤 분리: 앞쪽 절반은 상단(topPts: Left -> Right), 뒤쪽 절반은 하단(botPts: Right -> Left)
      const half = Math.floor(river.polygon.length / 2);
      const topPts = river.polygon.slice(0, half);
      const botPts = river.polygon.slice(half).reverse(); // botPts를 Left -> Right 순서로 통일

      const riverCenterY = area.centerY || (area.margin + area.height * 0.5);

      // 1. 오른쪽(East) 방향 연장
      while (topPts[topPts.length - 1].x < mapRight) {
        const lastIdx = topPts.length - 1;
        const curX = topPts[lastIdx].x;
        const nextX = Math.min(mapRight, curX + stepDist);

        const curCenterY = (topPts[lastIdx].y + botPts[lastIdx].y) * 0.5;
        const curOffset = curCenterY - riverCenterY;
        const delta = (Math.random() * 2 - 1) * 18;
        const nextOffset = Math.max(-75, Math.min(75, curOffset + delta));
        const nextY = riverCenterY + nextOffset;

        topPts.push({ x: nextX, y: nextY - riverWidth * 0.5 });
        botPts.push({ x: nextX, y: nextY + riverWidth * 0.5 });

        if (nextX >= mapRight) break;
      }

      // 2. 왼쪽(West) 방향 연장
      while (topPts[0].x > mapLeft) {
        const curX = topPts[0].x;
        const nextX = Math.max(mapLeft, curX - stepDist);

        const curCenterY = (topPts[0].y + botPts[0].y) * 0.5;
        const curOffset = curCenterY - riverCenterY;
        const delta = (Math.random() * 2 - 1) * 18;
        const nextOffset = Math.max(-75, Math.min(75, curOffset + delta));
        const nextY = riverCenterY + nextOffset;

        topPts.unshift({ x: nextX, y: nextY - riverWidth * 0.5 });
        botPts.unshift({ x: nextX, y: nextY + riverWidth * 0.5 });

        if (nextX <= mapLeft) break;
      }

      // botPts를 다시 역순으로 뒤집어 시계방향 폐곡선 폴리곤 재조립
      river.polygon = [...topPts, ...botPts.reverse()];
    }

    /**
     * 맵 확장 시 새로 확보된 영역을 포함하여 산 1~2개를 추가 배치한다.
     * - 기존 역(최소 85px 안전거리), 기존 산(최소 90px 안전거리), 강 지형과의 겹침을 엄격히 방지
     */
    spawnExpansionMountains() {
      const area = this.playArea;
      const count = Math.random() < 0.5 ? 1 : 2; // 매주 1~2개 추가
      const river = this.terrains.find(t => t.id === 'river_0');

      let spawnedCount = 0;

      for (let n = 0; n < count; n++) {
        for (let attempt = 0; attempt < 80; attempt++) {
          const rx = 75 + Math.random() * 55;  // 반지름 75~130
          const ry = 55 + Math.random() * 40;  // 반지름 55~95

          const minX = area.centerX - area.width * 0.48;
          const maxX = area.centerX + area.width * 0.48;
          const minY = area.centerY - area.height * 0.48;
          const maxY = area.centerY + area.height * 0.48;

          const cx = minX + Math.random() * (maxX - minX);
          const cy = minY + Math.random() * (maxY - minY);
          const center = { x: cx, y: cy };

          // 1. 강 지형과 너무 가까운지 확인 (강 중심선 기준 안전거리)
          const riverCenterY = area.centerY || (area.margin + area.height * 0.5);
          if (Math.abs(cy - riverCenterY) < ry + 65) {
            continue;
          }

          // 2. 기존 역들과 최소 안전거리 확인 (역 반지름 + 산 반지름 + 버퍼)
          let tooCloseToStation = false;
          for (const st of this.stations) {
            if (Geometry.dist(center, st.position) < Math.max(rx, ry) + 85) {
              tooCloseToStation = true;
              break;
            }
          }
          if (tooCloseToStation) continue;

          // 3. 기존 산들과 겹치는지 확인
          let overlapMountain = false;
          for (const t of this.terrains) {
            if (t.type !== 'MOUNTAIN' || !t.polygon) continue;
            let mCenter = { x: 0, y: 0 };
            for (const p of t.polygon) { mCenter.x += p.x; mCenter.y += p.y; }
            mCenter.x /= t.polygon.length;
            mCenter.y /= t.polygon.length;
            if (Geometry.dist(center, mCenter) < Math.max(rx, ry) + 90) {
              overlapMountain = true;
              break;
            }
          }
          if (overlapMountain) continue;

          // 4. 산 생성 및 강 폴리곤과의 정밀 충돌 검사
          const newMountain = this.generateMountain(center, rx, ry);
          if (river && river.polygon) {
            let hitsRiver = false;
            for (let i = 0; i < newMountain.polygon.length; i++) {
              const p1 = newMountain.polygon[i];
              const p2 = newMountain.polygon[(i + 1) % newMountain.polygon.length];
              if (Geometry.segmentIntersectsPolygon(p1, p2, river.polygon) ||
                  Geometry.pointInPolygon(p1, river.polygon)) {
                hitsRiver = true;
                break;
              }
            }
            if (hitsRiver) continue;
          }

          this.terrains.push(newMountain);
          spawnedCount++;
          break;
        }
      }
    }

    openWeeklyRewardModal(weekNum) {
      if (this.isGameOver) return;
      this.cancelConnecting();
      this.isRewardModalOpen = true;

      const badge = document.getElementById('weeklyRewardBadge');
      if (badge) badge.textContent = `제 ${weekNum}주차 도시 보급`;

      const desc = document.getElementById('weeklyRewardDesc');
      if (desc) {
        desc.textContent = '도시 구역이 1/6 확장되었습니다. 추가할 자원을 1가지 선택하세요.';
      }

      const modal = document.getElementById('weeklyRewardModal');
      if (modal) modal.classList.remove('hidden');

      this.sfx.play('connect');
      this.refreshCursor();
    }

    applyWeeklyReward(type) {
      if (!this.isRewardModalOpen) return;

      const trainCap = this.getTrainMaxCapacity();

      if (type === 'line') {
        this.availableLines += 1;
        this.availableTrains += 1;
        this.activeLineSlot = this.availableLines;
        this._renderedSlotCount = -1;
        this.logEvent(`주간 보급 적용 — ${this.availableLines}호선 슬롯 및 열차 +1 추가`);
        this.showToast(`${this.availableLines}호선 추가 완료 (숫자 ${this.availableLines} 키 선택)`);
      } else if (type === 'carriage') {
        // 열차 최대 정원은 15명(역 30명 : 열차 15명 = 2 : 1)으로 고정, 객차 추가 선택 시 기존 운행 노선에 새 열차 1대 추가 투입
        const validLines = this.lines.filter(l => l.stationIds.length >= 2);
        if (validLines.length > 0) {
          let targetLine = validLines[0];
          let bestMetric = Infinity;

          for (const line of validLines) {
            const trainsOnLine = this.trains.filter(t => t.lineId === line.id).length;
            let waitingSum = 0;
            for (const stId of line.stationIds) {
              const st = this.stations.find(s => s.id === stId);
              if (st) waitingSum += st.passengers.length;
            }
            const metric = trainsOnLine * 1000 - waitingSum;
            if (metric < bestMetric) {
              bestMetric = metric;
              targetLine = line;
            }
          }

          this.spawnTrainOnLine(targetLine, false, true);
          const countOnLine = this.trains.filter(t => t.lineId === targetLine.id).length;
          this.logEvent(`주간 보급 적용 — ${targetLine.name} 열차 +1 추가 투입 (운행 ${countOnLine}대 · 정원 ${trainCap}명)`);
          this.showToast(`${targetLine.name}에 새 열차 1대 투입 완료 (정원 ${trainCap}명)`);
        } else {
          this.extraPendingTrains += 1;
          this.logEvent(`주간 보급 적용 — 예비 열차 +1 확보 (노선 개통 시 추가 투입 · 정원 ${trainCap}명)`);
          this.showToast(`예비 열차 +1 확보 (첫 노선 개통 시 자동 투입)`);
        }
      } else if (type === 'station') {
        const created = this.spawnNewStation('주간 보급 역 추가', true);
        if (!created) {
          this.showToast('배치 가능한 여유 공간을 찾지 못해 다리 +1로 대체 지급되었습니다.');
          this.availableBridges += 1;
        }
      } else if (type === 'bridge') {
        this.availableBridges += 1;
        this.logEvent(`주간 보급 적용 — 다리 +1 추가 (보유 다리 ${this.availableBridges}개)`);
        this.showToast(`다리 +1 추가 완료 (보유 ${this.availableBridges}개)`);
      } else if (type === 'tunnel') {
        this.availableTunnels += 1;
        this.logEvent(`주간 보급 적용 — 터널 +1 추가 (보유 터널 ${this.availableTunnels}개)`);
        this.showToast(`터널 +1 추가 완료 (보유 ${this.availableTunnels}개)`);
      }

      const modal = document.getElementById('weeklyRewardModal');
      if (modal) modal.classList.add('hidden');
      this.isRewardModalOpen = false;

      this.sfx.play('click');
      this.updateHUD();
      this.refreshCursor();
    }

    spawnNewStation(reason, forceAllow = false) {
      if (!forceAllow && this.stations.length >= CONFIG.simulation.maxNaturalStations) {
        return null;
      }

      const area = this.playArea;
      const minX = area.centerX - area.width * 0.5 + 80;
      const maxX = area.centerX + area.width * 0.5 - 80;
      const minY = area.centerY - area.height * 0.5 + 80;
      const maxY = area.centerY + area.height * 0.5 - 80;

      const shapes = [SHAPES.CIRCLE, SHAPES.TRIANGLE, SHAPES.SQUARE];
      const colors = CONFIG.colors.stationColors;

      for (let attempt = 0; attempt < 180; attempt++) {
        const minDist = attempt < 130 ? CONFIG.station.minDistance : 115;
        const pos = {
          x: minX + Math.random() * (maxX - minX),
          y: minY + Math.random() * (maxY - minY)
        };

        let onTerrain = false;
        for (const t of this.terrains) {
          if (Geometry.pointInPolygon(pos, t.polygon)) {
            onTerrain = true;
            break;
          }
          if (t.type === 'MOUNTAIN' && t.polygon) {
            let mCenter = { x: 0, y: 0 };
            for (const p of t.polygon) { mCenter.x += p.x; mCenter.y += p.y; }
            mCenter.x /= t.polygon.length;
            mCenter.y /= t.polygon.length;
            if (Geometry.dist(pos, mCenter) < 85) {
              onTerrain = true;
              break;
            }
          }
        }
        if (onTerrain) continue;

        let tooClose = false;
        for (const s of this.stations) {
          if (Geometry.dist(pos, s.position) < minDist) {
            tooClose = true;
            break;
          }
        }
        if (tooClose) continue;

        if (this.stations.length > 0) {
          let hasAccessibleConnection = false;
          for (const s of this.stations) {
            const check = this.checkSegmentTerrain(pos, s.position);
            if (check.bridgeCount <= CONFIG.simulation.maxRequiredInfrastructure &&
                check.tunnelCount <= CONFIG.simulation.maxRequiredInfrastructure) {
              hasAccessibleConnection = true;
              break;
            }
          }
          if (!hasAccessibleConnection) continue;
        }

        const stationNumber = this.stations.length + 1;
        const newStation = {
          id: `s_${String(stationNumber).padStart(3, '0')}`,
          name: `역 ${String(stationNumber).padStart(2, '0')}`,
          position: pos,
          shape: shapes[Math.floor(Math.random() * shapes.length)],
          color: colors[Math.floor(Math.random() * colors.length)],
          passengers: [],
          connectedLineIds: [],
          warningStage: 0
        };

        this.stations.push(newStation);
        const reasonTag = reason ? ` (${reason})` : '';
        this.logEvent(`신규 역 개통 — ${newStation.name}${reasonTag}`);
        this.showToast(`신규 역 개통: ${newStation.name}`);
        this.sfx.play('click');
        return newStation;
      }

      return null;
    }

    triggerGameOver(station) {
      if (this.isGameOver) return;
      this.isGameOver = true;
      this.isRewardModalOpen = false;
      this.cancelConnecting();
      this.sfx.play('gameover');

      const warnBanner = document.getElementById('warningBanner');
      if (warnBanner) warnBanner.classList.add('hidden');
      const rewardModal = document.getElementById('weeklyRewardModal');
      if (rewardModal) rewardModal.classList.add('hidden');

      const survivedDays = this.getCurrentDay();
      const finalScore = (this.totalArrivedPassengers * 10) + (survivedDays * 50) + (this.lines.length * 25);
      this.score = Math.max(this.score, finalScore);

      const modal = document.getElementById('gameOverModal');
      if (modal) {
        modal.classList.remove('hidden');
        document.getElementById('goTotalScore').textContent = this.score.toLocaleString();
        document.getElementById('goPassengers').textContent = `${this.totalArrivedPassengers.toLocaleString()}명`;
        document.getElementById('goDays').textContent = `${survivedDays}일`;
        document.getElementById('goLines').textContent = `${this.lines.length}개`;
        document.getElementById('gameOverReason').textContent =
          `${station.name} 대기 인원이 한도(${CONFIG.station.maxPassengers}명)에 도달해 운행이 중단되었습니다.`;
      }
      this.refreshCursor();
    }

    // ==========================================================================
    // 8. 적응형 명도 마우스 커서 (밝은 곳 검은색 / 어두운 곳 흰색)
    // ==========================================================================
    updateAdaptiveCursor(clientX, clientY) {
      if (clientX < 0 || clientY < 0 || clientX >= window.innerWidth || clientY >= window.innerHeight) {
        return;
      }

      let r = 248, g = 246, b = 240;

      if (this.ctx && this.canvas.width > 0 && this.canvas.height > 0) {
        const px = Math.max(0, Math.min(this.canvas.width - 1, Math.floor(clientX)));
        const py = Math.max(0, Math.min(this.canvas.height - 1, Math.floor(clientY)));
        try {
          const data = this.ctx.getImageData(px, py, 1, 1).data;
          if (data && data.length >= 3) {
            r = data[0];
            g = data[1];
            b = data[2];
          }
        } catch (_) {
          // 로컬 캔버스 전용이나 안전 폴백 유지
        }
      }

      if (typeof document.elementsFromPoint === 'function') {
        const stack = document.elementsFromPoint(clientX, clientY);
        for (let i = stack.length - 1; i >= 0; i--) {
          const el = stack[i];
          if (!el || el === document.documentElement || el === document.body || el === this.canvas) continue;
          const tag = el.tagName ? el.tagName.toLowerCase() : '';
          if (tag === 'svg' || tag === 'path' || tag === 'circle' || tag === 'rect') continue;

          const style = window.getComputedStyle(el);
          const bg = Geometry.parseCssRgba(style.backgroundColor);
          if (bg && bg.a > 0.01) {
            const a = Math.max(0, Math.min(1, bg.a));
            r = r * (1 - a) + bg.r * a;
            g = g * (1 - a) + bg.g * a;
            b = b * (1 - a) + bg.b * a;
          }
        }
      }

      const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
      const shouldBeWhite = luminance < CONFIG.cursor.luminanceThreshold;

      if (shouldBeWhite !== this.isCursorWhite) {
        this.isCursorWhite = shouldBeWhite;
        document.documentElement.style.setProperty(
          '--active-cursor',
          shouldBeWhite ? 'var(--cursor-white)' : 'var(--cursor-black)'
        );
      }
    }

    refreshCursor() {
      if (this.mouseScreenPos.x >= 0 && this.mouseScreenPos.y >= 0) {
        this.updateAdaptiveCursor(this.mouseScreenPos.x, this.mouseScreenPos.y);
      }
    }

    // ==========================================================================
    // 9. 렌더링 시스템 (Nordic Architectural Light)
    // ==========================================================================
    render() {
      const ctx = this.ctx;
      const width = this.canvas.width;
      const height = this.canvas.height;

      ctx.fillStyle = CONFIG.colors.paper;
      ctx.fillRect(0, 0, width, height);

      ctx.save();
      ctx.translate(width * 0.5, height * 0.5);
      ctx.scale(this.camera.zoom, this.camera.zoom);
      ctx.translate(-this.camera.x, -this.camera.y);

      this.renderGrid(ctx);
      this.renderTerrains(ctx);
      this.renderLines(ctx);
      this.renderConnectionPreview(ctx);
      this.renderStations(ctx);
      this.renderTrains(ctx);
      this.renderLastConnectedStations(ctx);

      ctx.restore();
    }

    renderGrid(ctx) {
      const area = this.playArea;
      const spacing = CONFIG.grid.cellSizePx;
      const minX = area.centerX - area.width * 0.5;
      const maxX = area.centerX + area.width * 0.5;
      const minY = area.centerY - area.height * 0.5;
      const maxY = area.centerY + area.height * 0.5;

      ctx.strokeStyle = CONFIG.colors.grid;
      ctx.lineWidth = 1;
      ctx.beginPath();

      const startX = Math.floor(minX / spacing) * spacing;
      for (let x = startX; x <= maxX; x += spacing) {
        if (x >= minX) {
          ctx.moveTo(x, minY);
          ctx.lineTo(x, maxY);
        }
      }
      const startY = Math.floor(minY / spacing) * spacing;
      for (let y = startY; y <= maxY; y += spacing) {
        if (y >= minY) {
          ctx.moveTo(minX, y);
          ctx.lineTo(maxX, y);
        }
      }
      ctx.stroke();

      ctx.strokeStyle = '#D5CEC2';
      ctx.lineWidth = 2;
      ctx.strokeRect(minX, minY, area.width, area.height);
    }

    renderTerrains(ctx) {
      for (const t of this.terrains) {
        ctx.beginPath();
        ctx.moveTo(t.polygon[0].x, t.polygon[0].y);
        for (let i = 1; i < t.polygon.length; i++) {
          ctx.lineTo(t.polygon[i].x, t.polygon[i].y);
        }
        ctx.closePath();

        if (t.type === 'RIVER') {
          ctx.fillStyle = CONFIG.colors.river;
          ctx.fill();
          ctx.strokeStyle = CONFIG.colors.riverBank;
          ctx.lineWidth = 2.2;
          ctx.stroke();
        } else if (t.type === 'MOUNTAIN') {
          ctx.fillStyle = CONFIG.colors.mountain;
          ctx.fill();
          ctx.strokeStyle = CONFIG.colors.mountainStroke;
          ctx.lineWidth = 2.0;
          ctx.stroke();
        }
      }
    }

    renderLines(ctx) {
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';

      for (const seg of this.getRenderedLineSegments()) {
        ctx.strokeStyle = seg.line.color;
        ctx.lineWidth = 6;
        ctx.beginPath();
        ctx.moveTo(seg.p1.x, seg.p1.y);
        ctx.lineTo(seg.p2.x, seg.p2.y);
        ctx.stroke();
      }

      // 다리 마커
      for (const b of this.bridges) {
        ctx.fillStyle = '#FFFFFF';
        ctx.strokeStyle = '#15529E';
        ctx.lineWidth = 2;
        ctx.fillRect(b.pos.x - 10, b.pos.y - 6, 20, 12);
        ctx.strokeRect(b.pos.x - 10, b.pos.y - 6, 20, 12);
        ctx.beginPath();
        ctx.moveTo(b.pos.x - 10, b.pos.y);
        ctx.lineTo(b.pos.x + 10, b.pos.y);
        ctx.stroke();
      }

      // 터널 아치 마커
      for (const tu of this.tunnels) {
        ctx.fillStyle = '#FFFFFF';
        ctx.strokeStyle = '#334155';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(tu.pos.x, tu.pos.y, 10, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = '#334155';
        ctx.beginPath();
        ctx.arc(tu.pos.x, tu.pos.y + 2, 5.2, Math.PI, 0, false);
        ctx.lineTo(tu.pos.x + 5.2, tu.pos.y + 5);
        ctx.lineTo(tu.pos.x - 5.2, tu.pos.y + 5);
        ctx.closePath();
        ctx.fill();
      }
    }

    renderConnectionPreview(ctx) {
      if (this.isDeleteMode && this.hoveredDeleteSegment) {
        const hit = this.hoveredDeleteSegment;
        const liveLine = this.lines.find(l => l.id === hit.line.id);
        if (!liveLine) {
          this.hoveredDeleteSegment = null;
          return;
        }
        const plan = this.computeSegmentDeletionPlan(liveLine, hit.segIdx);
        if (plan) {
          const affectedSet = new Set(plan.affectedSegIndices);
          const allSegs = this.getRenderedLineSegments().filter(
            s => s.line.id === hit.line.id && affectedSet.has(s.segIdx)
          );

          ctx.save();
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';

          // 삭제 예정 구간 붉은 글로우 + 점선 강조
          for (const s of allSegs) {
            ctx.strokeStyle = 'rgba(220, 38, 38, 0.28)';
            ctx.lineWidth = 14;
            ctx.setLineDash([]);
            ctx.beginPath();
            ctx.moveTo(s.p1.x, s.p1.y);
            ctx.lineTo(s.p2.x, s.p2.y);
            ctx.stroke();

            ctx.strokeStyle = '#DC2626';
            ctx.lineWidth = 6.5;
            ctx.setLineDash([8, 6]);
            ctx.beginPath();
            ctx.moveTo(s.p1.x, s.p1.y);
            ctx.lineTo(s.p2.x, s.p2.y);
            ctx.stroke();
          }

          // 분리될 역들 강조 링
          ctx.setLineDash([4, 4]);
          ctx.strokeStyle = 'rgba(220, 38, 38, 0.85)';
          ctx.lineWidth = 2.4;
          for (const stId of plan.removedStationIds) {
            const st = this.stations.find(item => item.id === stId);
            if (!st) continue;
            ctx.beginPath();
            ctx.arc(st.position.x, st.position.y, CONFIG.station.radius + 7, 0, Math.PI * 2);
            ctx.stroke();
          }
          ctx.setLineDash([]);

          // 삭제 안내 툴팁 (커서/투영점 상단)
          let label;
          if (plan.deletesWholeLine) {
            label = `클릭: ${hit.line.name} 전체 철거`;
          } else if (plan.opensLoop) {
            label = `클릭: ${hit.line.name} 이 구간 해제 (순환 해제)`;
          } else if (plan.affectedSegIndices.length === 1) {
            label = `클릭: ${hit.line.name} 끝 구간 삭제`;
          } else {
            label = `클릭: ${hit.line.name} 구간 ${plan.affectedSegIndices.length}개 삭제 (종점까지)`;
          }

          const tipPos = hit.proj || this.mouseWorldPos;
          ctx.font = `700 11.5px ${this.canvasFontFamily}`;
          const tw = ctx.measureText(label).width;
          const bw = tw + 16;
          const bh = 22;
          const bx = tipPos.x - bw * 0.5;
          const by = tipPos.y - 34;

          ctx.fillStyle = 'rgba(255, 255, 255, 0.96)';
          ctx.strokeStyle = '#DC2626';
          ctx.lineWidth = 1.6;
          ctx.beginPath();
          if (typeof ctx.roundRect === 'function') {
            ctx.roundRect(bx, by, bw, bh, 6);
          } else {
            ctx.rect(bx, by, bw, bh);
          }
          ctx.fill();
          ctx.stroke();

          ctx.fillStyle = '#B91C1C';
          ctx.textAlign = 'center';
          ctx.fillText(label, tipPos.x, by + 15);
          ctx.restore();
        }
        return;
      }

      if (!this.connectingFromStation) return;

      const p1 = this.connectingFromStation.position;
      let p2 = this.mouseWorldPos;
      let targetStation = null;

      if (this.hoveredStation && this.hoveredStation.id !== this.connectingFromStation.id) {
        p2 = this.hoveredStation.position;
        targetStation = this.hoveredStation;
      }

      const plan = this.resolveConnectionPlan(this.connectingFromStation, targetStation);
      const terrainCheck = this.checkSegmentTerrain(p1, p2);
      const distMeters = Math.round((Geometry.dist(p1, p2) / CONFIG.grid.cellSizePx) * 10) / 10;

      let blocked = !plan.ok;
      let statusLabel = plan.ok ? `${plan.lineName} 연결 · ${distMeters}m` : plan.reason;
      const costLabels = [];

      if (terrainCheck.bridgeCount > this.availableBridges) {
        blocked = true;
        statusLabel = `다리 부족 (${this.availableBridges}/${terrainCheck.bridgeCount})`;
      } else if (terrainCheck.tunnelCount > this.availableTunnels) {
        blocked = true;
        statusLabel = `터널 부족 (${this.availableTunnels}/${terrainCheck.tunnelCount})`;
      } else if (plan.ok) {
        if (terrainCheck.bridgeCount > 0) costLabels.push(`다리 ${terrainCheck.bridgeCount}`);
        if (terrainCheck.tunnelCount > 0) costLabels.push(`터널 ${terrainCheck.tunnelCount}`);
        if (costLabels.length > 0) {
          statusLabel = `${plan.lineName} 연결 · ${distMeters}m (${costLabels.join(' · ')} 사용)`;
        } else if (plan.mode === 'CLOSE_LOOP') {
          statusLabel = `${plan.lineName} 순환선 완성 · ${distMeters}m`;
        } else if (plan.branchedFromCircular) {
          statusLabel = `${plan.lineName} 분기 · ${distMeters}m (${plan.branchedFromCircular} 유지)`;
        }
      }

      const previewColor = blocked ? '#C92A2A' : plan.color;

      ctx.strokeStyle = previewColor;
      ctx.lineWidth = 3.2;
      ctx.beginPath();
      ctx.arc(p1.x, p1.y, 28, 0, Math.PI * 2);
      ctx.stroke();

      if (targetStation) {
        ctx.strokeStyle = blocked ? 'rgba(201, 42, 42, 0.22)' : 'rgba(21, 82, 158, 0.18)';
        ctx.lineWidth = 12;
        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.stroke();

        ctx.strokeStyle = previewColor;
        ctx.lineWidth = 6;
        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.stroke();

        ctx.lineWidth = 3.5;
        ctx.beginPath();
        ctx.arc(p2.x, p2.y, 31, 0, Math.PI * 2);
        ctx.stroke();

        ctx.font = `700 12px ${this.canvasFontFamily}`;
        ctx.fillStyle = previewColor;
        ctx.textAlign = 'center';
        ctx.fillText(statusLabel, p2.x, p2.y - 38);
      } else {
        ctx.setLineDash([8, 6]);
        ctx.strokeStyle = previewColor;
        ctx.lineWidth = 4.5;
        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.stroke();
        ctx.setLineDash([]);

        ctx.fillStyle = previewColor;
        ctx.beginPath();
        ctx.arc(p2.x, p2.y, 5.5, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = previewColor;
        ctx.lineWidth = 1.8;
        ctx.beginPath();
        ctx.arc(p2.x, p2.y, 13, 0, Math.PI * 2);
        ctx.stroke();

        ctx.font = `700 12px ${this.canvasFontFamily}`;
        ctx.fillStyle = previewColor;
        ctx.textAlign = 'left';
        ctx.fillText(statusLabel, p2.x + 18, p2.y - 6);
      }
    }

    renderStations(ctx) {
      for (const st of this.stations) {
        const pos = st.position;
        let size = CONFIG.station.radius;
        let outlineColor = CONFIG.colors.stationOutline;
        let outlineWidth = 3.5;

        if (this.hoveredStation && this.hoveredStation.id === st.id) {
          size = 22.5;
          outlineWidth = 4;
          ctx.strokeStyle = 'rgba(21, 82, 158, 0.55)';
          ctx.lineWidth = 2.2;
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, size + 7, 0, Math.PI * 2);
          ctx.stroke();
        }

        if ((this.selectedStation && this.selectedStation.id === st.id) ||
            (this.connectingFromStation && this.connectingFromStation.id === st.id)) {
          ctx.strokeStyle = '#15529E';
          ctx.lineWidth = 2.8;
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, size + 9, 0, Math.PI * 2);
          ctx.stroke();
        }

        const count = st.passengers.length;
        const warnStage = this.getStationWarningStage(count);

        if (warnStage === 3) {
          outlineColor = '#C92A2A';
          outlineWidth = 5;
          ctx.strokeStyle = 'rgba(201, 42, 42, 0.35)';
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, size + 6, 0, Math.PI * 2);
          ctx.stroke();
        } else if (warnStage === 2) {
          outlineColor = '#EA580C';
          outlineWidth = 4.8;
          ctx.strokeStyle = 'rgba(234, 88, 12, 0.3)';
          ctx.lineWidth = 2.5;
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, size + 5.5, 0, Math.PI * 2);
          ctx.stroke();
        } else if (warnStage === 1) {
          outlineColor = '#D97706';
          outlineWidth = 4.4;
        }

        ctx.fillStyle = st.color;
        ctx.strokeStyle = outlineColor;
        ctx.lineWidth = outlineWidth;

        if (st.shape === SHAPES.CIRCLE) {
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, size, 0, Math.PI * 2);
          ctx.fill();
          ctx.stroke();

          ctx.fillStyle = '#FFFFFF';
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, 5, 0, Math.PI * 2);
          ctx.fill();
        } else if (st.shape === SHAPES.TRIANGLE) {
          ctx.beginPath();
          ctx.moveTo(pos.x, pos.y - size * 1.15);
          ctx.lineTo(pos.x + size, pos.y + size * 0.7);
          ctx.lineTo(pos.x - size, pos.y + size * 0.7);
          ctx.closePath();
          ctx.fill();
          ctx.stroke();

          ctx.fillStyle = '#FFFFFF';
          ctx.beginPath();
          ctx.arc(pos.x, pos.y + size * 0.1, 4, 0, Math.PI * 2);
          ctx.fill();
        } else if (st.shape === SHAPES.SQUARE) {
          ctx.beginPath();
          ctx.rect(pos.x - size, pos.y - size, size * 2, size * 2);
          ctx.fill();
          ctx.stroke();

          ctx.fillStyle = '#FFFFFF';
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, 5, 0, Math.PI * 2);
          ctx.fill();
        }

        if (st.overflowTimer > 0) {
          const graceSec = CONFIG.station.overflowGraceSec || 1.0;
          const ratio = Math.min(1, st.overflowTimer / graceSec);
          ctx.save();
          ctx.strokeStyle = 'rgba(201, 42, 42, 0.25)';
          ctx.lineWidth = 5;
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, size + 10, 0, Math.PI * 2);
          ctx.stroke();

          ctx.strokeStyle = '#C92A2A';
          ctx.lineWidth = 5;
          ctx.lineCap = 'round';
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, size + 10, -Math.PI * 0.5, -Math.PI * 0.5 + Math.PI * 2 * ratio);
          ctx.stroke();
          ctx.restore();
        }

        if (count > 0) {
          let labelText = `${count}`;
          let labelColor = '#181C20';
          let borderCol = '#D2D8E0';

          if (count >= CONFIG.station.maxPassengers && (st.overflowTimer || 0) > 0) {
            const graceSec = CONFIG.station.overflowGraceSec || 1.0;
            const remain = Math.max(0, graceSec - st.overflowTimer);
            labelText = `${count} · 유예 ${remain.toFixed(1)}초`;
            labelColor = '#C92A2A';
            borderCol = '#EF4444';
          } else if (warnStage === 3) {
            labelText = `${count} · 3차 경고`;
            labelColor = '#C92A2A';
            borderCol = '#FCA5A5';
          } else if (warnStage === 2) {
            labelText = `${count} · 2차 경고`;
            labelColor = '#C2410C';
            borderCol = '#FDBA74';
          } else if (warnStage === 1) {
            labelText = `${count} · 1차 경고`;
            labelColor = '#B45309';
            borderCol = '#FCD34D';
          }

          ctx.font = `700 11.5px ${this.canvasFontFamily}`;
          const textWidth = ctx.measureText(labelText).width;
          const badgeW = textWidth + 12;
          const badgeH = 18;

          ctx.fillStyle = 'rgba(255, 255, 255, 0.96)';
          ctx.strokeStyle = borderCol;
          ctx.lineWidth = 1.2;
          ctx.fillRect(pos.x - badgeW * 0.5, pos.y - size - 23, badgeW, badgeH);
          ctx.strokeRect(pos.x - badgeW * 0.5, pos.y - size - 23, badgeW, badgeH);

          ctx.fillStyle = labelColor;
          ctx.textAlign = 'center';
          ctx.fillText(labelText, pos.x, pos.y - size - 10);
        }

        this.renderStationPassengers(ctx, st, pos);
      }
    }

    renderStationPassengers(ctx, station, pos) {
      const pCount = Math.min(station.passengers.length, CONFIG.station.maxPassengers);
      const iconSize = 4.2;
      const cols = 6;

      for (let i = 0; i < pCount; i++) {
        const p = station.passengers[i];
        const px = pos.x + (i % cols) * 9.5 - 23.75;
        const py = pos.y + Math.floor(i / cols) * 10 + 28;

        ctx.fillStyle = p.targetColor;
        ctx.strokeStyle = '#1E293B';
        ctx.lineWidth = 1;

        if (p.targetShape === SHAPES.CIRCLE) {
          ctx.beginPath();
          ctx.arc(px, py, iconSize, 0, Math.PI * 2);
          ctx.fill();
          ctx.stroke();
        } else if (p.targetShape === SHAPES.TRIANGLE) {
          ctx.beginPath();
          ctx.moveTo(px, py - iconSize);
          ctx.lineTo(px + iconSize * 0.866, py + iconSize * 0.5);
          ctx.lineTo(px - iconSize * 0.866, py + iconSize * 0.5);
          ctx.closePath();
          ctx.fill();
          ctx.stroke();
        } else if (p.targetShape === SHAPES.SQUARE) {
          ctx.beginPath();
          ctx.rect(px - iconSize, py - iconSize, iconSize * 2, iconSize * 2);
          ctx.fill();
          ctx.stroke();
        }
      }
    }

    renderTrains(ctx) {
      const cap = this.getTrainMaxCapacity(); // 정원 15명 (역 30명 : 열차 15명 = 2 : 1)
      for (const train of this.trains) {
        const line = this.lines.find(l => l.id === train.lineId);
        if (!line || line.stationIds.length < 2) continue;

        const pos = this.getTrainWorldPosition(train, line);
        if (!pos) continue;

        const trainW = 30;
        const trainH = 15;

        ctx.fillStyle = '#FFFFFF';
        ctx.strokeStyle = '#1F2937';
        ctx.lineWidth = 1.5;
        ctx.fillRect(pos.x - trainW * 0.5, pos.y - trainH * 0.5, trainW, trainH);
        ctx.strokeRect(pos.x - trainW * 0.5, pos.y - trainH * 0.5, trainW, trainH);

        ctx.fillStyle = line.color;
        ctx.fillRect(pos.x - trainW * 0.5, pos.y - trainH * 0.5, trainW, 4);

        if (train.passengers.length > 0) {
          ctx.font = `700 9.5px ${this.canvasMonoFontFamily}`;
          ctx.fillStyle = '#181C20';
          ctx.textAlign = 'center';
          ctx.fillText(`${train.passengers.length}/${cap}`, pos.x, pos.y + 4.5);
        }
      }
    }

    /**
     * 노선별 가장 마지막으로 이은 역 조회
     */
    getLineLastStation(line) {
      if (!line || !line.stationIds || line.stationIds.length === 0) return null;
      let targetId = line.lastConnectedStationId;
      if (!targetId || !line.stationIds.includes(targetId)) {
        targetId = line.stationIds[line.stationIds.length - 1];
      }
      return this.stations.find(s => s.id === targetId) || null;
    }

    /**
     * 노선별 첫 역(시점 / 순환선 연결 대상 역) 조회
     */
    getLineFirstStation(line) {
      if (!line || !line.stationIds || line.stationIds.length === 0) return null;
      let targetId = line.stationIds[0];
      if (!line.isCircular && line.stationIds.length >= 2 && line.lastConnectedStationId === targetId) {
        targetId = line.stationIds[line.stationIds.length - 1];
      }
      return this.stations.find(s => s.id === targetId) || null;
    }

    /**
     * W 키 단축키: 노선별 가장 마지막으로 연결된 종점/최근 역 하이라이트 토글
     */
    toggleLastStationHighlight() {
      if (this.lines.length === 0) {
        this.showToast('개통된 노선이 없습니다. 먼저 노선을 개통하세요.');
        this.sfx.play('warn');
        return;
      }

      this.showLastStationMarkers = !this.showLastStationMarkers;
      this.sfx.play('click');

      const btn = document.getElementById('btnToolLastStation');
      if (btn) btn.classList.toggle('active', this.showLastStationMarkers);

      if (this.showLastStationMarkers) {
        const summaries = this.lines.map(l => {
          const st = this.getLineLastStation(l);
          return st ? `${l.name}: ${st.name}` : null;
        }).filter(Boolean);

        this.showToast('노선별 마지막 연결 역 표시 켜짐 (W 키로 끄기)');
        this.logEvent(`[W] 노선별 마지막 연결 역: ${summaries.join(' · ')}`);
      } else {
        this.showToast('노선별 마지막 연결 역 표시 해제');
      }
    }

    /**
     * E 키 단축키: 노선별 첫 역(순환선 연결 대상) 하이라이트 토글
     */
    toggleFirstStationHighlight() {
      if (this.lines.length === 0) {
        this.showToast('개통된 노선이 없습니다. 먼저 노선을 개통하세요.');
        this.sfx.play('warn');
        return;
      }

      this.showFirstStationMarkers = !this.showFirstStationMarkers;
      this.sfx.play('click');

      const btn = document.getElementById('btnToolFirstStation');
      if (btn) btn.classList.toggle('active', this.showFirstStationMarkers);

      if (this.showFirstStationMarkers) {
        const summaries = this.lines.map(l => {
          const st = this.getLineFirstStation(l);
          return st ? `${l.name}: ${st.name}` : null;
        }).filter(Boolean);

        this.showToast('노선별 첫 역 표시 켜짐 (E 키로 끄기)');
        this.logEvent(`[E] 노선별 첫 역: ${summaries.join(' · ')}`);
      } else {
        this.showToast('노선별 첫 역 표시 해제');
      }
    }

    /**
     * 캔버스 위 노선별 마지막 연결 역(W) 및 첫 역(E) 배지·펄싱 하이라이트 렌더링
     */
    renderLastConnectedStations(ctx) {
      if ((!this.showLastStationMarkers && !this.showFirstStationMarkers) || this.lines.length === 0) return;

      const now = performance.now();
      const pulse = Math.sin(now * 0.006) * 3.5;

      const stationMap = new Map();

      for (const line of this.lines) {
        if (!line.stationIds || line.stationIds.length === 0) continue;

        if (this.showLastStationMarkers) {
          const lastSt = this.getLineLastStation(line);
          if (lastSt) {
            if (!stationMap.has(lastSt.id)) {
              stationMap.set(lastSt.id, []);
            }
            stationMap.get(lastSt.id).push({ line, station: lastSt, kind: 'last' });
          }
        }

        if (this.showFirstStationMarkers) {
          const firstSt = this.getLineFirstStation(line);
          if (firstSt) {
            if (!stationMap.has(firstSt.id)) {
              stationMap.set(firstSt.id, []);
            }
            stationMap.get(firstSt.id).push({ line, station: firstSt, kind: 'first' });
          }
        }
      }

      for (const [stId, items] of stationMap.entries()) {
        const st = items[0].station;
        const pos = st.position;

        // 1. 역 외곽 펄싱 하이라이트 링
        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          const ringRadius = CONFIG.station.radius + 9 + i * 5 + pulse;
          ctx.save();
          ctx.strokeStyle = item.line.color;
          ctx.lineWidth = 2.4;
          if (item.kind === 'first') {
            ctx.setLineDash([6, 4]);
          }
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, ringRadius, 0, Math.PI * 2);
          ctx.stroke();
          ctx.restore();
        }

        // 2. 역 상단 노선 정보 배지 카드
        const badgeStartY = pos.y - CONFIG.station.radius - 24;

        items.forEach((item, idx) => {
          let badgeText;
          if (item.kind === 'first') {
            badgeText = item.line.isCircular
              ? `${item.line.name} 첫 역 (순환)`
              : `${item.line.name} 첫 역`;
          } else {
            badgeText = item.line.isCircular
              ? `${item.line.name} (순환)`
              : `${item.line.name} 마지막 역`;
          }

          ctx.font = `700 11px ${this.canvasFontFamily}`;
          const textWidth = ctx.measureText(badgeText).width;
          const badgeW = textWidth + 24;
          const badgeH = 20;
          const badgeX = pos.x;
          const badgeY = badgeStartY - idx * 23;

          ctx.save();
          ctx.shadowColor = 'rgba(0, 0, 0, 0.14)';
          ctx.shadowBlur = 6;
          ctx.shadowOffsetY = 2;

          ctx.fillStyle = '#FFFFFF';
          ctx.strokeStyle = item.line.color;
          ctx.lineWidth = 2;
          ctx.beginPath();
          if (typeof ctx.roundRect === 'function') {
            ctx.roundRect(badgeX - badgeW * 0.5, badgeY - badgeH * 0.5, badgeW, badgeH, 5);
          } else {
            ctx.rect(badgeX - badgeW * 0.5, badgeY - badgeH * 0.5, badgeW, badgeH);
          }
          ctx.fill();
          ctx.stroke();
          ctx.restore();

          // 노선 색상 점(Dot) 마커
          ctx.fillStyle = item.line.color;
          ctx.beginPath();
          ctx.arc(badgeX - badgeW * 0.5 + 9.5, badgeY, 3.5, 0, Math.PI * 2);
          ctx.fill();

          // 텍스트 라벨
          ctx.fillStyle = '#1C2024';
          ctx.textAlign = 'left';
          ctx.fillText(badgeText, badgeX - badgeW * 0.5 + 18, badgeY + 3.8);
        });
      }
    }

    // ==========================================================================
    // 10. 입력 이벤트 및 단축키 (1, 2, 4 배속 단축키 제거 → 1~9 호선 지정)
    // ==========================================================================
    initEvents() {
      window.addEventListener('mousemove', (e) => {
        this.mouseScreenPos = { x: e.clientX, y: e.clientY };
        this.updateAdaptiveCursor(e.clientX, e.clientY);
      }, { passive: true });

      this.canvas.addEventListener('mousedown', (e) => {
        if (this.isRewardModalOpen || this.isGameOver || this.isControlsGuideOpen) return;
        const worldPos = this.screenToWorld(e.clientX, e.clientY);

        if (e.button === 0) {
          const clickedStation = this.findStationAt(worldPos);

          if (this.isDeleteMode) {
            const clickedSeg = this.findLineSegmentAt(worldPos);
            if (clickedSeg) {
              this.deleteLineFromSegment(clickedSeg);
            } else {
              this.isDraggingCamera = true;
              this.dragStartPos = { x: e.clientX, y: e.clientY };
            }
            return;
          }

          if (clickedStation) {
            if (this.connectingFromStation && this.connectingFromStation.id !== clickedStation.id) {
              this.connectStations(this.connectingFromStation, clickedStation);
              this.cancelConnecting();
            } else if (this.connectingFromStation && this.connectingFromStation.id === clickedStation.id) {
              this.cancelConnecting();
            } else {
              this.connectingFromStation = clickedStation;
              this.selectedStation = clickedStation;
              this.updateInspector();
              this.showConnectingBanner(clickedStation);
              this.sfx.play('click');
            }
          } else {
            if (this.connectingFromStation) {
              this.cancelConnecting();
            }
            this.selectedStation = null;
            this.updateInspector();
            this.isDraggingCamera = true;
            this.dragStartPos = { x: e.clientX, y: e.clientY };
          }
        } else if (e.button === 2) {
          if (this.isDeleteMode) {
            this.setDeleteMode(false, true);
          } else if (this.connectingFromStation) {
            this.cancelConnecting();
          } else {
            this.isDraggingCamera = true;
            this.dragStartPos = { x: e.clientX, y: e.clientY };
          }
        }
      });

      this.canvas.addEventListener('mousemove', (e) => {
        this.mouseWorldPos = this.screenToWorld(e.clientX, e.clientY);

        if (this.isDraggingCamera) {
          const dx = (e.clientX - this.dragStartPos.x) / this.camera.zoom;
          const dy = (e.clientY - this.dragStartPos.y) / this.camera.zoom;
          this.camera.x -= dx;
          this.camera.y -= dy;
          this.dragStartPos = { x: e.clientX, y: e.clientY };
        }

        const prevHovered = this.hoveredStation;
        this.hoveredStation = this.findStationAt(this.mouseWorldPos);
        if (prevHovered !== this.hoveredStation) {
          this.updateInspector();
        }

        if (this.isDeleteMode) {
          this.hoveredDeleteSegment = this.findLineSegmentAt(this.mouseWorldPos);
        } else if (this.hoveredDeleteSegment) {
          this.hoveredDeleteSegment = null;
        }
      });

      window.addEventListener('mouseup', (e) => {
        if (this.isDraggingCamera) {
          this.isDraggingCamera = false;
        }

        if (!this.isRewardModalOpen && !this.isGameOver && !this.isControlsGuideOpen && this.connectingFromStation && e.button === 0) {
          const target = this.findStationAt(this.mouseWorldPos);
          if (target && target.id !== this.connectingFromStation.id) {
            this.connectStations(this.connectingFromStation, target);
            this.cancelConnecting();
          }
        }
      });

      this.canvas.addEventListener('wheel', (e) => {
        e.preventDefault();
        if (this.isRewardModalOpen || this.isControlsGuideOpen) return;
        const factor = e.deltaY < 0 ? 1.12 : 0.89;
        const mouseBefore = this.screenToWorld(e.clientX, e.clientY);

        this.camera.zoom = Math.min(Math.max(this.camera.zoom * factor, 0.4), 2.8);

        const mouseAfter = this.screenToWorld(e.clientX, e.clientY);
        this.camera.x += (mouseBefore.x - mouseAfter.x);
        this.camera.y += (mouseBefore.y - mouseAfter.y);

        const zoomDisplay = document.getElementById('zoomLevelDisplay');
        if (zoomDisplay) zoomDisplay.textContent = `${Math.round(this.camera.zoom * 100)}%`;
      }, { passive: false });

      this.canvas.addEventListener('contextmenu', e => e.preventDefault());

      window.addEventListener('keyup', (e) => {
        if (e.code === 'KeyQ' || e.key === 'q' || e.key === 'Q' || e.key === 'ㅂ' || e.key === 'ㅃ') {
          this.isQKeyDown = false;
        }
      });

      window.addEventListener('blur', () => {
        this.isQKeyDown = false;
        this.isQSpeedModeActive = false;
      });

      // 키보드 단축키: Ctrl/Q+(숫자) 1~10 배속 설정 및 단독 숫자 1~9 호선 지정
      window.addEventListener('keydown', (e) => {
        if (this.isControlsGuideOpen) {
          if (e.key === 'Control' || e.key === 'Shift' || e.key === 'Alt' || e.key === 'Meta') {
            return;
          }
          if (e.key === 'Escape' || e.key === 'h' || e.key === 'H' || e.key === 'Enter') {
            e.preventDefault();
            this.closeControlsGuide();
            return;
          }
          this.closeControlsGuide();
        }

        if ((e.ctrlKey || e.metaKey) && (e.key === 'z' || e.key === 'Z')) {
          e.preventDefault();
          if (!this.isRewardModalOpen) {
            if (e.shiftKey) this.redo();
            else this.undo();
          }
          return;
        }
        if ((e.ctrlKey || e.metaKey) && (e.key === 'y' || e.key === 'Y')) {
          e.preventDefault();
          if (!this.isRewardModalOpen) this.redo();
          return;
        }

        if (this.isRewardModalOpen || this.isGameOver) return;

        // Q 키: 배속 제어 모드 (누른 상태 또는 연속 입력 프리픽스)
        const isQ = e.code === 'KeyQ' || e.key === 'q' || e.key === 'Q' || e.key === 'ㅂ' || e.key === 'ㅃ';
        if (isQ) {
          e.preventDefault();
          this.isQKeyDown = true;
          this.isQSpeedModeActive = true;
          if (this.qSpeedModeTimeout) {
            clearTimeout(this.qSpeedModeTimeout);
          }
          this.qSpeedModeTimeout = setTimeout(() => {
            this.isQSpeedModeActive = false;
          }, 1800);

          if (!e.repeat) {
            this.showToast('배속 설정 모드: 숫자 1~9 (1~9배속), 0 (10배속)');
          }
          return;
        }

        let inputDigit = null;
        if (/^[0-9]$/.test(e.key)) {
          inputDigit = Number(e.key);
        } else if (e.code && e.code.startsWith('Digit')) {
          const d = e.code.replace('Digit', '');
          if (/^[0-9]$/.test(d)) inputDigit = Number(d);
        } else if (e.code && e.code.startsWith('Numpad')) {
          const d = e.code.replace('Numpad', '');
          if (/^[0-9]$/.test(d)) inputDigit = Number(d);
        }

        if (inputDigit !== null) {
          if (e.shiftKey && !e.ctrlKey && !e.metaKey && !e.altKey) {
            e.preventDefault();
            const targetSpeed = inputDigit === 0 ? 10 : inputDigit;
            this.setSpeed(targetSpeed);
            return;
          }

          if ((e.ctrlKey || e.metaKey) && !e.altKey) {
            e.preventDefault();
            const targetSpeed = inputDigit === 0 ? 10 : inputDigit;
            this.setSpeed(targetSpeed);
            return;
          }

          if (this.isQKeyDown || this.isQSpeedModeActive) {
            e.preventDefault();
            if (this.qSpeedModeTimeout) {
              clearTimeout(this.qSpeedModeTimeout);
              this.qSpeedModeTimeout = null;
            }
            this.isQSpeedModeActive = false;

            const now = Date.now();
            let targetSpeed = inputDigit === 0 ? 10 : inputDigit;
            // 1 누른 직후 빠르게 0을 입력한 경우 (10배속 연속 입력 보조)
            if (inputDigit === 0 && this.lastQDigit === 1 && (now - this.lastQDigitTime < 600)) {
              targetSpeed = 10;
            }

            this.lastQDigit = inputDigit;
            this.lastQDigitTime = now;
            this.setSpeed(targetSpeed);
            return;
          }

          // Q 조합이 아닌 단독 숫자 1~9: 연결할 호선 슬롯 직접 지정
          if (!e.ctrlKey && !e.metaKey && !e.altKey && inputDigit >= 1 && inputDigit <= 9) {
            e.preventDefault();
            this.selectLineSlot(inputDigit);
            return;
          }
        }

        if (e.code === 'Space') {
          e.preventDefault();
          this.togglePause();
        } else if (e.key === 'Escape') {
          if (this.isDeleteMode) {
            this.setDeleteMode(false, true);
          } else {
            this.cancelConnecting();
          }
        } else if (e.key === 'c' || e.key === 'C' || e.key === 'Home') {
          this.centerCamera();
        } else if (e.code === 'KeyW' || e.key === 'w' || e.key === 'W') {
          e.preventDefault();
          this.toggleLastStationHighlight();
        } else if (e.code === 'KeyE' || e.key === 'e' || e.key === 'E') {
          e.preventDefault();
          this.toggleFirstStationHighlight();
        } else if (e.code === 'KeyX' || e.key === 'x' || e.key === 'X') {
          e.preventDefault();
          this.toggleDeleteMode();
        } else if (e.key === 'Delete') {
          e.preventDefault();
          this.deleteLine(this.activeLineSlot);
        } else if (e.key === 'Backspace') {
          e.preventDefault();
          this.trimLineLastSegment(this.activeLineSlot);
        } else if (e.key === 'h' || e.key === 'H' || e.key === '?') {
          e.preventDefault();
          this.toggleControlsGuide();
        } else if (e.key === 'l' || e.key === 'L') {
          if (this.isDeleteMode) this.setDeleteMode(false, false);
          this.showToast(`현재 선택: ${this.activeLineSlot}호선 (숫자 1~${this.availableLines} 키로 변경)`);
        } else if (e.key === 'b' || e.key === 'B') {
          this.showToast(`보유 다리: ${this.availableBridges}개 (1일마다 +1 정기 지급)`);
        } else if (e.key === 't' || e.key === 'T') {
          this.showToast(`보유 터널: ${this.availableTunnels}개 (2일마다 +1 정기 지급)`);
        } else if (e.key === 'u' || e.key === 'U') {
          this.undo();
        } else if (e.key === 'r' || e.key === 'R') {
          this.redo();
        }
      }, { capture: true });

      this.bindUIButtons();
    }

    bindUIButtons() {
      document.getElementById('btnPause').onclick = () => this.togglePause();
      document.getElementById('btnSpeed1').onclick = () => this.setSpeed(1);
      document.getElementById('btnSpeed2').onclick = () => this.setSpeed(2);
      document.getElementById('btnSpeed4').onclick = () => this.setSpeed(4);
      const btnSpeedCustom = document.getElementById('btnSpeedCustom');
      if (btnSpeedCustom) {
        btnSpeedCustom.onclick = () => {
          this.showToast(`현재 ${this.speed}배속 · Shift+(1~9: 1~9배속, 0: 10배속) 또는 Q+숫자`);
        };
      }
      this.setSpeed(this.speed, false);

      document.getElementById('btnToolLine').onclick = () => {
        if (this.isDeleteMode) this.setDeleteMode(false, false);
        this.showToast(`현재 선택: ${this.activeLineSlot}호선 (숫자 1~${this.availableLines} 키로 호선 지정)`);
      };
      document.getElementById('btnToolBridge').onclick = () =>
        this.showToast(`보유 다리: ${this.availableBridges}개 (강 통과 시 자동 건설 · 1일마다 +1)`);
      document.getElementById('btnToolTunnel').onclick = () =>
        this.showToast(`보유 터널: ${this.availableTunnels}개 (산 통과 시 자동 건설 · 2일마다 +1)`);
      const btnToolLastStation = document.getElementById('btnToolLastStation');
      if (btnToolLastStation) {
        btnToolLastStation.onclick = () => this.toggleLastStationHighlight();
      }
      const btnToolFirstStation = document.getElementById('btnToolFirstStation');
      if (btnToolFirstStation) {
        btnToolFirstStation.onclick = () => this.toggleFirstStationHighlight();
      }
      const btnToolDeleteLine = document.getElementById('btnToolDeleteLine');
      if (btnToolDeleteLine) {
        btnToolDeleteLine.onclick = () => this.toggleDeleteMode();
      }
      document.getElementById('btnUndo').onclick = () => this.undo();
      document.getElementById('btnRedo').onclick = () => this.redo();
      document.getElementById('btnCenterCam').onclick = () => this.centerCamera();

      document.getElementById('btnAudioToggle').onclick = () => {
        const on = this.sfx.toggle();
        const svgOn = document.getElementById('audioSvgOn');
        const svgOff = document.getElementById('audioSvgOff');
        const label = document.getElementById('audioStateLabel');
        if (svgOn) svgOn.classList.toggle('hidden', !on);
        if (svgOff) svgOff.classList.toggle('hidden', on);
        if (label) label.textContent = on ? '음향 켜짐' : '음소거';
        this.showToast(on ? '효과음 켜짐' : '효과음 음소거');
      };

      const fontButtons = document.querySelectorAll('#fontPickerGrid .font-option');
      fontButtons.forEach(btn => {
        btn.onclick = () => this.setFontPreset(btn.dataset.font, true);
      });

      const btnToolHelp = document.getElementById('btnToolHelp');
      if (btnToolHelp) {
        btnToolHelp.onclick = () => this.toggleControlsGuide();
      }

      const btnCloseGuide = document.getElementById('btnCloseControlsGuide');
      if (btnCloseGuide) {
        btnCloseGuide.onclick = () => this.closeControlsGuide();
      }

      const btnCloseGuideX = document.getElementById('btnCloseControlsGuideX');
      if (btnCloseGuideX) {
        btnCloseGuideX.onclick = () => this.closeControlsGuide();
      }

      const guideModal = document.getElementById('controlsGuideModal');
      if (guideModal) {
        guideModal.onclick = (e) => {
          if (e.target === guideModal) {
            this.closeControlsGuide();
          }
        };
      }

      document.getElementById('btnCancelConnect').onclick = () => {
        if (this.isDeleteMode) this.setDeleteMode(false, true);
        else this.cancelConnecting();
      };
      const closeBtn = document.getElementById('btnCloseInspector');
      if (closeBtn) {
        closeBtn.onclick = () => {
          this.selectedStation = null;
          this.updateInspector();
        };
      }
      document.getElementById('btnRestartGame').onclick = () => {
        document.getElementById('gameOverModal').classList.add('hidden');
        this.initMap();
        this.centerCamera();
      };

      // 주간 5종 보급 선택 버튼
      const rewardModal = document.getElementById('weeklyRewardModal');
      if (rewardModal && typeof rewardModal.querySelectorAll === 'function') {
        const rewardBtns = rewardModal.querySelectorAll('.reward-option');
        for (const btn of rewardBtns) {
          btn.onclick = () => {
            const type = btn.getAttribute('data-reward');
            if (type) this.applyWeeklyReward(type);
          };
        }
      }
    }

    screenToWorld(sx, sy) {
      const cx = this.canvas.width * 0.5;
      const cy = this.canvas.height * 0.5;
      return {
        x: (sx - cx) / this.camera.zoom + this.camera.x,
        y: (sy - cy) / this.camera.zoom + this.camera.y
      };
    }

    findStationAt(worldPos) {
      const r = CONFIG.station.radius + 12;
      for (const st of this.stations) {
        if (Geometry.dist(worldPos, st.position) < r) return st;
      }
      return null;
    }

    cancelConnecting() {
      this.connectingFromStation = null;
      const banner = document.getElementById('connectingBanner');
      if (banner) banner.classList.add('hidden');
    }

    showConnectingBanner(station) {
      const banner = document.getElementById('connectingBanner');
      const text = document.getElementById('connectingBannerText');
      const dot = document.getElementById('connectingBannerDot');
      if (!banner || !text) return;

      const plan = this.resolveConnectionPlan(station, null);
      if (dot) dot.style.backgroundColor = plan.color;

      const modeLabel = plan.branchedFromCircular
        ? `${plan.lineName} 분기 (${plan.branchedFromCircular} 유지)`
        : plan.lineName;
      text.textContent = `${station.name} → ${modeLabel} 연결 중 · 숫자 키(1~${this.availableLines}) 호선 변경 · ESC 취소`;
      banner.classList.remove('hidden');
    }

    centerCamera() {
      this.camera.x = this.playArea.centerX;
      this.camera.y = this.playArea.centerY;
      this.camera.zoom = 0.95;
      const zoomDisplay = document.getElementById('zoomLevelDisplay');
      if (zoomDisplay) zoomDisplay.textContent = '95%';
      this.showToast('카메라 중앙 정렬');
    }

    togglePause() {
      this.isPaused = !this.isPaused;
      document.getElementById('btnPause').classList.toggle('active', this.isPaused);
      this.showToast(this.isPaused ? '일시정지' : '운행 재개');
    }

    openControlsGuide() {
      this.isControlsGuideOpen = true;
      const modal = document.getElementById('controlsGuideModal');
      if (modal) modal.classList.remove('hidden');
    }

    closeControlsGuide() {
      this.isControlsGuideOpen = false;
      const modal = document.getElementById('controlsGuideModal');
      if (modal) modal.classList.add('hidden');
      this.showToast('운행이 시작되었습니다. 언제든 좌측 도움말(H)로 확인할 수 있습니다.');
    }

    toggleControlsGuide() {
      if (this.isControlsGuideOpen) {
        this.closeControlsGuide();
      } else {
        this.openControlsGuide();
      }
    }

    setSpeed(s, notify = true) {
      const minS = (CONFIG.simulation && CONFIG.simulation.minSpeed) || 1;
      const maxS = (CONFIG.simulation && CONFIG.simulation.maxSpeed) || 10;
      const clamped = Math.max(minS, Math.min(maxS, Math.round(s)));
      this.speed = clamped;
      this.isPaused = false;
      const btnPause = document.getElementById('btnPause');
      if (btnPause) btnPause.classList.remove('active');

      const btn1 = document.getElementById('btnSpeed1');
      const btn2 = document.getElementById('btnSpeed2');
      const btn4 = document.getElementById('btnSpeed4');
      const btnCustom = document.getElementById('btnSpeedCustom');

      if (btn1) btn1.classList.toggle('active', clamped === 1);
      if (btn2) btn2.classList.toggle('active', clamped === 2);
      if (btn4) btn4.classList.toggle('active', clamped === 4);

      if (btnCustom) {
        if (clamped !== 1 && clamped !== 2 && clamped !== 4) {
          btnCustom.textContent = `${clamped}x`;
          btnCustom.classList.remove('hidden');
          btnCustom.classList.add('active');
          btnCustom.title = `현재 배속: ${clamped}배속 (단축키: Shift+1~9, Shift+0 또는 Q+숫자)`;
        } else {
          btnCustom.classList.add('hidden');
          btnCustom.classList.remove('active');
        }
      }

      if (notify) {
        this.showToast(`${clamped}배속 운행`);
      }
    }

    setBadgeAvailability(badgeEl, isAvailable) {
      if (!badgeEl) return;
      badgeEl.classList.toggle('is-available', isAvailable);
      badgeEl.classList.toggle('is-empty', !isAvailable);
    }

    // ==========================================================================
    // 11. HUD 및 우측 하단 역 정보 텍스트 업데이트
    // ==========================================================================
    renderLineSlotButtons() {
      const container = document.getElementById('lineSlotButtons');
      if (!container) return;

      if (this._renderedSlotCount !== this.availableLines) {
        container.innerHTML = '';
        for (let s = 1; s <= this.availableLines; s++) {
          const btn = document.createElement('button');
          btn.type = 'button';
          btn.id = `lineSlotBtn_${s}`;
          btn.className = 'line-slot-btn';
          btn.style.setProperty('--slot-color', this.getSlotColor(s));
          btn.onclick = () => this.selectLineSlot(s);
          btn.oncontextmenu = (e) => {
            e.preventDefault();
            this.deleteLine(s);
          };
          container.appendChild(btn);
        }
        this._renderedSlotCount = this.availableLines;
      }

      for (let s = 1; s <= this.availableLines; s++) {
        const btn = document.getElementById(`lineSlotBtn_${s}`);
        if (!btn) continue;
        const line = this.getLineBySlot(s);
        const isBuilt = Boolean(line);
        const isCircular = Boolean(line && line.isCircular);
        const isSelected = this.activeLineSlot === s;

        btn.classList.toggle('is-built', isBuilt);
        btn.classList.toggle('is-selected', isSelected);
        btn.textContent = isCircular ? `${s}↻` : `${s}`;
        btn.title = isCircular
          ? `${s}호선 (순환 운행 중 · 숫자 ${s} / 우클릭 철거)`
          : (isBuilt ? `${s}호선 연장 (숫자 ${s} / 우클릭 철거)` : `${s}호선 신설 대기 (숫자 ${s})`);
      }
    }

    updateHUD() {
      const currentDay = this.getCurrentDay();
      const totalSec = Math.floor(((this.simTime % 86400) + 86400) % 86400);
      const hours = String(Math.floor(totalSec / 3600)).padStart(2, '0');
      const mins = String(Math.floor((totalSec % 3600) / 60)).padStart(2, '0');
      document.getElementById('timeDisplay').textContent = `Day ${currentDay} · ${hours}:${mins}`;

      const mapBadge = document.getElementById('mapExpandBadge');
      if (mapBadge) {
        if (this.playArea.expansionWeek > 0) {
          const metrics = this.getPlayAreaMetrics();
          mapBadge.classList.remove('hidden');
          mapBadge.textContent = `지도 +${metrics.expandPct}%`;
          mapBadge.title = `제 ${this.playArea.expansionWeek}주차 도시 확장 (주간 가로·세로 +1/6)`;
        } else {
          mapBadge.classList.add('hidden');
        }
      }

      document.getElementById('passengersDisplay').textContent = this.totalArrivedPassengers.toLocaleString();
      document.getElementById('scoreDisplay').textContent = this.score.toLocaleString();

      this.renderLineSlotButtons();

      const totalTrains = this.availableTrains + this.extraPendingTrains + this.trains.length;
      const trainCap = this.getTrainMaxCapacity();

      document.getElementById('resLineCount').textContent = `${this.lines.length}/${this.availableLines}`;
      document.getElementById('resBridgeCount').textContent = this.availableBridges;
      document.getElementById('resTunnelCount').textContent = this.availableTunnels;
      document.getElementById('resTrainCount').textContent = totalTrains;
      const carriageEl = document.getElementById('resCarriageCount');
      if (carriageEl) carriageEl.textContent = `${trainCap}명`;

      this.setBadgeAvailability(document.getElementById('resBridgeBadge'), this.availableBridges > 0);
      this.setBadgeAvailability(document.getElementById('resTunnelBadge'), this.availableTunnels > 0);
      this.setBadgeAvailability(document.getElementById('resTrainBadge'), totalTrains > 0);
      this.setBadgeAvailability(document.getElementById('resCarriageBadge'), trainCap > 0);

      const railBridgeCount = document.getElementById('railBridgeCount');
      const railTunnelCount = document.getElementById('railTunnelCount');
      const btnToolBridge = document.getElementById('btnToolBridge');
      const btnToolTunnel = document.getElementById('btnToolTunnel');

      if (railBridgeCount) {
        railBridgeCount.textContent = this.availableBridges;
        railBridgeCount.classList.toggle('is-empty', this.availableBridges <= 0);
      }
      if (btnToolBridge) {
        btnToolBridge.classList.toggle('is-empty', this.availableBridges <= 0);
      }
      if (railTunnelCount) {
        railTunnelCount.textContent = this.availableTunnels;
        railTunnelCount.classList.toggle('is-empty', this.availableTunnels <= 0);
      }
      if (btnToolTunnel) {
        btnToolTunnel.classList.toggle('is-empty', this.availableTunnels <= 0);
      }

      this.updateWarningBanner();
      this.updateInspector();
    }

    updateInspector() {
      const panel = document.getElementById('inspectorPanel');
      const primaryEl = document.getElementById('inspectLinePrimary');
      const secondaryEl = document.getElementById('inspectLineSecondary');
      if (!panel || !primaryEl || !secondaryEl) return;

      const hovered = this.hoveredStation ? this.stations.find(s => s.id === this.hoveredStation.id) : null;
      const selected = this.selectedStation ? this.stations.find(s => s.id === this.selectedStation.id) : null;
      const st = hovered || selected;

      if (!st) {
        panel.classList.add('hidden');
        return;
      }

      panel.classList.remove('hidden');

      const shapeName = st.shape === SHAPES.CIRCLE ? '원형' : (st.shape === SHAPES.TRIANGLE ? '삼각형' : '사각형');
      const count = st.passengers.length;
      const warnStage = this.getStationWarningStage(count);

      let statusLabel = '정상';
      primaryEl.classList.remove('is-warn-1', 'is-warn-2', 'is-warn-3');
      if (warnStage === 3) {
        statusLabel = '3차 경고';
        primaryEl.classList.add('is-warn-3');
      } else if (warnStage === 2) {
        statusLabel = '2차 경고';
        primaryEl.classList.add('is-warn-2');
      } else if (warnStage === 1) {
        statusLabel = '1차 경고';
        primaryEl.classList.add('is-warn-1');
      }

      primaryEl.textContent = `${st.name} (${shapeName}) · 대기 ${count}/${CONFIG.station.maxPassengers}명 · ${statusLabel}`;

      const connectedLines = this.lines.filter(l => l.stationIds.includes(st.id));
      const lineSummary = connectedLines.length === 0
        ? '없음'
        : connectedLines.map(l => (l.isCircular ? `${l.name}(순환)` : l.name)).join(', ');
      secondaryEl.textContent = `경유 노선: ${lineSummary}`;
    }

    logEvent(text) {
      this.eventLogs.unshift(text);
      if (this.eventLogs.length > 20) this.eventLogs.pop();
      const el = document.getElementById('eventLogText');
      if (el) el.textContent = text;
    }

    showToast(msg, tone = '') {
      const toast = document.getElementById('toastMessage');
      if (toast) {
        toast.textContent = msg;
        toast.classList.remove('hidden', 'toast-warn-1', 'toast-warn-2', 'toast-warn-3');
        if (tone) {
          toast.classList.add(`toast-${tone}`);
        }
        clearTimeout(this._toastTimer);
        this._toastTimer = setTimeout(() => {
          toast.classList.add('hidden');
        }, 2800);
      }
    }
  }

  // ==========================================================================
  // 12. 부트스트랩 및 루프 실행
  // ==========================================================================
  window.addEventListener('DOMContentLoaded', () => {
    const canvas = document.getElementById('gameCanvas');
    const game = new SubwayGame(canvas);

    let lastTime = performance.now();
    let frameTick = 0;
    function loop(now) {
      const dt = Math.min((now - lastTime) / 1000, 0.1);
      lastTime = now;

      game.update(dt);
      game.render();
      if ((++frameTick % 6) === 0) {
        game.refreshCursor();
      }

      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
  });
})();
