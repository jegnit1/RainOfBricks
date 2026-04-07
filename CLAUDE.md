# Rain of Bricks — Claude Code 프로젝트 지침

## 프로젝트 개요
- **엔진**: Godot 4.6 (GL Compatibility 렌더러, D3D12/Windows)
- **장르**: 2D 플랫포머 로그라이크 — 벽돌 낙하를 피하며 채굴·전투하는 게임
- **언어**: GDScript

## 디렉토리 구조
```
rain-of-bricks/
├── scripts/
│   ├── entities/   # 개별 오브젝트 스크립트 (player, brick, robot, kiosk, key, stage_door, treasure_chest, wall_block)
│   ├── game/       # 게임 진행 시스템 (GameManager, StageManager, GameScene, Map, BrickSpawner, RobotSpawner)
│   └── ui/         # UI 스크립트 (hud, level_up_panel)
├── scenes/
│   ├── entities/   # 씬 파일 (scripts/entities 대응)
│   ├── game/       # 씬 파일 (scripts/game 대응)
│   └── ui/         # 씬 파일 (scripts/ui 대응)
├── data/
│   ├── player_base.json   # 플레이어 기본 스탯 (DB → export_all.bat)
│   ├── exp_table.json     # 레벨별 요구 경험치
│   ├── stages.json        # 스테이지 설정 (brick_hp_mult, robot_hp_mult 포함)
│   ├── robots.json        # 로봇 적 데이터
│   ├── stat_options.json  # 레벨업 스탯 선택지
│   └── wall_blocks.json   # 벽 블록 설정
├── assets/         # 이미지, 사운드 등 리소스
├── RainOfBricks_ItemDB.db  # 아이템+플레이어+스테이지+블록+로봇 SQLite DB
├── db_migration.sql        # DB 테이블/뷰 초기화 SQL
└── export_all.bat          # DB → 모든 JSON 일괄 내보내기
```

## 핵심 시스템 구조

### Autoload (전역 싱글톤)
- **GameManager** (`scripts/game/GameManager.gd`) — 게임 전역 상태 관리
  - 재화(currency), 경험치/레벨, 무게(weight), 게임오버 처리
  - 시그널: `game_over_started`, `game_over`, `weight_changed`, `currency_changed`, `weight_stage_changed`, `exp_changed`, `level_up`
- **StageManager** (`scripts/game/StageManager.gd`) — 스테이지 진행 관리
  - 스테이지 데이터 로드, 벽돌 스폰 카운트, 스테이지 클리어 감지
  - 시그널: `stage_cleared`, `stage_started`

### 플레이어 (`scripts/entities/player.gd`)
- `CharacterBody2D` 기반, 이동/점프/공격/채굴/산소 시스템
- 공격: 마우스 방향 기반 히트박스, 공속 쿨타임
- 채굴: 우클릭, 인접 블록만 가능, dig_power/dig_speed 스탯 적용
- 산소: 벽 안에 있으면 감소, 0이 되면 지속 데미지
- 레벨업 시 `stat_selected` 시그널로 스탯 증가 처리

### 물리 레이어
| 레이어 | 이름 |
|--------|------|
| 1 | world |
| 2 | player |
| 3 | brick |
| 4 | monster |
| 5 | wall |

### 입력 액션
| 액션 | 키 |
|------|----|
| move_left | A / ← |
| move_right | D / → |
| jump | Space |
| attack | 마우스 좌클릭 |
| dig | 마우스 우클릭 |
| action | W / ↑ |

## 코딩 컨벤션
- GDScript 표준 스타일 (snake_case 변수/함수, PascalCase 클래스/시그널 없는 경우 snake_case)
- 시그널 이름은 snake_case, 이벤트 의미를 동사 과거형 또는 명사로 표현
- JSON 데이터는 `data/` 폴더에서 `_ready()`에 로드
- 노드 참조는 `get_node()` 또는 `@onready` 사용
- GameManager/StageManager는 Autoload이므로 어디서든 직접 접근 가능

## 아이템/게임 데이터 DB
- `RainOfBricks_ItemDB.db` — SQLite, 아이템/플레이어/스테이지/블록/로봇 통합 DB
- `db_migration.sql` — DB 테이블/뷰 생성 스크립트 (최초 1회 실행)
- `export_all.bat` — DB → 모든 JSON 일괄 내보내기 (밸런스 수정 후 반드시 실행)
- JSON 파일들은 내보내기 결과물. 직접 편집 금지 (DB에서 관리)
