-- ============================================================
-- 로스트아크 레이드 기록 - Supabase 테이블 설정
-- Supabase 대시보드 > SQL Editor 에 붙여넣고 실행하세요.
-- 이미 테이블이 있는 경우 하단 [마이그레이션] 섹션만 실행하세요.
-- ============================================================

-- ── 1. 캐릭터 테이블 ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS characters (
    id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    name         TEXT        NOT NULL,
    item_level   NUMERIC(6,1),
    class        TEXT,
    server       TEXT,                        -- 서버명 (API 불러오기 시 자동 입력)
    roster_group UUID,                        -- 같이 불러온 캐릭터 묶음 (UUID)
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. 레이드 기록 테이블 ────────────────────────────────────
--    character_id가 NULL = 캐릭터가 삭제된 경우 (이름은 스냅샷 보존)
CREATE TABLE IF NOT EXISTS raid_records (
    id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    character_id    UUID        REFERENCES characters(id) ON DELETE SET NULL,
    character_name  TEXT        NOT NULL,    -- 삭제 후에도 이름 보존
    character_class TEXT,
    date            DATE        NOT NULL,
    raid_time       TIME,                    -- 시작 시간 (선택)
    raid_name       TEXT        NOT NULL,
    difficulty      TEXT        NOT NULL,
    memo            TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. Row Level Security (공개 접근 허용) ───────────────────
ALTER TABLE characters   ENABLE ROW LEVEL SECURITY;
ALTER TABLE raid_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_characters_all"   ON characters   FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_raid_records_all" ON raid_records FOR ALL USING (true) WITH CHECK (true);

-- ── 4. 인덱스 ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_raid_date    ON raid_records (date DESC, raid_time);
CREATE INDEX IF NOT EXISTS idx_raid_char    ON raid_records (character_id);


-- ============================================================
-- [마이그레이션] 이미 테이블이 존재하는 경우 아래만 실행
-- ============================================================

-- server 컬럼 추가 (처음 설치 시 이미 포함됨)
ALTER TABLE characters   ADD COLUMN IF NOT EXISTS server TEXT;

-- raid_time 컬럼 추가
ALTER TABLE raid_records ADD COLUMN IF NOT EXISTS raid_time TIME;

-- roster_group 컬럼 추가 (같이 불러온 캐릭터 묶음)
ALTER TABLE characters   ADD COLUMN IF NOT EXISTS roster_group UUID;

-- difficulty 체크 제약 제거 (커스텀 난이도 허용)
ALTER TABLE raid_records DROP CONSTRAINT IF EXISTS raid_records_difficulty_check;

-- batch_id 추가 (같이 저장한 기록끼리 묶음)
ALTER TABLE raid_records ADD COLUMN IF NOT EXISTS batch_id UUID;
CREATE INDEX IF NOT EXISTS idx_raid_batch ON raid_records(batch_id);
CREATE INDEX IF NOT EXISTS idx_chars_roster_group ON characters(roster_group);

-- ── 앱 설정 테이블 (레이드 목록 등) ─────────────────────────
CREATE TABLE IF NOT EXISTS app_settings (
  key        TEXT        PRIMARY KEY,
  value      JSONB       NOT NULL DEFAULT '[]'::jsonb
);
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_settings_all" ON app_settings FOR ALL USING (true) WITH CHECK (true);
