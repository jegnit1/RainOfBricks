-- ============================================================
-- Rain of Bricks DB Migration
-- SQLite Browser 또는 sqlite3 CLI에서 실행
-- ============================================================

-- ── 1. 플레이어 기본 스탯 ──────────────────────────────────
CREATE TABLE IF NOT EXISTS player_base_stats (
    key         TEXT PRIMARY KEY,
    value       REAL NOT NULL,
    description TEXT
);

INSERT OR REPLACE INTO player_base_stats VALUES
    ('max_hp',              100.0,  '최대 체력'),
    ('hp_regen',              0.0,  '초당 체력 회복량'),
    ('move_speed',          200.0,  '이동 속도'),
    ('jump_velocity',      -400.0,  '점프력 (음수 = 위쪽)'),
    ('weapon_reach',         48.0,  '무기 사거리'),
    ('weapon_width',         32.0,  '무기 폭'),
    ('weapon_damage',        10.0,  '무기 기본 공격력'),
    ('weapon_attack_speed',   1.5,  '초당 공격 횟수'),
    ('dig_power',            20.0,  '채굴력'),
    ('dig_speed',             1.0,  '채굴 속도 배율'),
    ('dig_cooldown',          0.4,  '채굴 쿨타임(초)'),
    ('dig_reach',            32.0,  '채굴 사거리'),
    ('dig_width',            24.0,  '채굴 폭'),
    ('luck',                  0.0,  '드롭 운 (높을수록 좋은 아이템)'),
    ('interest_rate',         0.0,  '스테이지 이자율'),
    ('fall_dmg_reduction',    0.0,  '낙하 피해 감소량'),
    ('gold_gain_mult',        1.0,  '전체 재화 획득 배율'),
    ('robot_gold_mult',       1.0,  '로봇 처치 재화 배율'),
    ('mine_gold_mult',        1.0,  '채굴 재화 배율'),
    ('kiosk_price_mult',      1.0,  '상점 가격 배율');

-- ── 2. 벽 블록 (기존 wall_blocks.json 흡수) ──────────────
CREATE TABLE IF NOT EXISTS wall_blocks (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    hp              INTEGER NOT NULL,
    color_r         REAL DEFAULT 0.4,
    color_g         REAL DEFAULT 0.4,
    color_b         REAL DEFAULT 0.4,
    treasure_chance REAL DEFAULT 0.1
);

INSERT OR REPLACE INTO wall_blocks VALUES
    ('wall_basic', '기본 벽',  120, 0.4, 0.4, 0.40, 0.10),
    ('wall_hard',  '강화 벽',  250, 0.3, 0.3, 0.35, 0.20);

-- ── 3. 로봇 (기존 robots.json 흡수) ─────────────────────
CREATE TABLE IF NOT EXISTS robots (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    hp               INTEGER NOT NULL,
    weight           REAL DEFAULT 15.0,
    move_speed       REAL DEFAULT 80.0,
    jump_velocity    REAL DEFAULT -300.0,
    power_duration   REAL DEFAULT 15.0,
    damage           INTEGER DEFAULT 10,
    damage_interval  REAL DEFAULT 0.5,
    currency_value   INTEGER DEFAULT 15,
    exp_value        INTEGER DEFAULT 20,
    can_enter_tunnel INTEGER DEFAULT 0
);

INSERT OR REPLACE INTO robots VALUES
    ('robot_basic',      '기본 로봇',      50,  15.0,  80.0, -300.0, 15.0, 10, 0.5, 15, 20, 0),
    ('robot_high_power', '고출력 로봇',    80,  20.0,  90.0, -350.0, 12.0, 15, 0.5, 25, 35, 0),
    ('robot_infinite',   '무한동력 로봇', 120,  25.0,  70.0, -280.0, -1.0, 20, 0.5, 40, 50, 0);

-- ── 4. 스테이지 (기존 stages.json 고도화) ────────────────
CREATE TABLE IF NOT EXISTS stages (
    stage                INTEGER PRIMARY KEY,
    max_weight           INTEGER NOT NULL,
    brick_count          INTEGER NOT NULL,
    brick_spawn_interval REAL    NOT NULL,
    brick_hp_mult        REAL    DEFAULT 1.0,  -- 블록 기본 HP 에 곱하는 배율
    robot_enabled        INTEGER DEFAULT 0,
    robot_spawn_interval REAL    DEFAULT 999.0,
    robot_hp_mult        REAL    DEFAULT 1.0   -- 로봇 기본 HP 에 곱하는 배율
);

INSERT OR REPLACE INTO stages VALUES
    (1, 100,  20, 2.0, 1.0, 0, 999.0, 1.0),
    (2, 120,  25, 1.5, 1.2, 1,  15.0, 1.0),
    (3, 150,  30, 1.2, 1.5, 1,  12.0, 1.3),
    (4, 180,  35, 1.0, 1.8, 1,  10.0, 1.5),
    (5, 220,  40, 0.8, 2.2, 1,   8.0, 1.8);

-- ── 뷰: JSON 내보내기용 ──────────────────────────────────
CREATE VIEW IF NOT EXISTS view_player_base AS
    SELECT key, value, description FROM player_base_stats;

CREATE VIEW IF NOT EXISTS view_wall_blocks AS
    SELECT
        id, name, hp,
        json_array(color_r, color_g, color_b) AS color,
        treasure_chance
    FROM wall_blocks;

CREATE VIEW IF NOT EXISTS view_robots AS
    SELECT
        id, name, hp, weight, move_speed, jump_velocity,
        power_duration, damage, damage_interval,
        currency_value, exp_value,
        CASE can_enter_tunnel WHEN 1 THEN 'true' ELSE 'false' END AS can_enter_tunnel
    FROM robots;

CREATE VIEW IF NOT EXISTS view_stages AS
    SELECT
        stage, max_weight, brick_count, brick_spawn_interval,
        brick_hp_mult, robot_enabled, robot_spawn_interval, robot_hp_mult
    FROM stages;
