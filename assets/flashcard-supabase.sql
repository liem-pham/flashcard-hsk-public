-- =====================================================================
-- Flashcard HSK (webapp public) — tạo bảng đồng bộ tiến độ trên Supabase
-- Project: bogreitxdmtplvcidfyk
--
-- Cách dùng: mở Supabase Dashboard → SQL Editor → dán toàn bộ file này
-- → Run. File chạy lại được nhiều lần an toàn (IF NOT EXISTS /
-- DROP POLICY IF EXISTS), chạy trùng không lỗi, không mất dữ liệu.
--
-- Thiết kế: tiến độ gắn theo device_id — mỗi trình duyệt tự sinh một
-- mã thiết bị ngẫu nhiên (xem trong Cài đặt của app). Nhập cùng một
-- mã thiết bị trên máy khác là học tiếp đúng tiến độ đó.
-- Ngoài các cột tối thiểu, flashcard_progress có thêm difficulty /
-- state / first_reviewed_at để trạng thái FSRS-7 khôi phục chính xác
-- từng thẻ khi chuyển máy.
--
-- RLS theo đúng mẫu bảng saved_words của app đọc báo: bật RLS, anon
-- được SELECT/INSERT/UPDATE/DELETE. Đây là đơn giản hoá cho một người
-- dùng, chưa có đăng nhập — ai có anon key và biết device_id đều đọc
-- được dữ liệu của device_id đó; khi nào thêm tài khoản thì siết lại
-- policy theo chủ sở hữu.
-- =====================================================================

create table if not exists public.flashcard_progress (
  device_id         text not null,
  word_id           text not null,
  stability_slow    double precision not null,
  stability_fast    double precision not null,
  difficulty        double precision not null default 0,
  state             text not null default 'review',
  due_at            timestamptz not null,
  last_reviewed_at  timestamptz not null,
  first_reviewed_at timestamptz not null,
  reps              integer not null default 0,
  lapses            integer not null default 0,
  primary key (device_id, word_id)
);

-- Nhật ký chấm thẻ, chỉ thêm (append-only), không sửa/xoá dòng cũ.
create table if not exists public.flashcard_reviews (
  id            bigint generated always as identity primary key,
  device_id     text not null,
  word_id       text not null,
  rating        integer not null,          -- 1 = Quên (Again), 3 = Nhớ (Good)
  reviewed_at   timestamptz not null,
  interval_days double precision not null
);
create index if not exists flashcard_reviews_device_idx
  on public.flashcard_reviews (device_id, reviewed_at);

create table if not exists public.flashcard_settings (
  device_id        text primary key,
  selected_lessons jsonb not null default '{}'::jsonb,
  example_pinyin   boolean not null default false,
  example_vi       boolean not null default false,
  updated_at       timestamptz not null default now()
);

alter table public.flashcard_progress enable row level security;
alter table public.flashcard_reviews  enable row level security;
alter table public.flashcard_settings enable row level security;

-- Quyền ở mức bảng cho role anon (RLS policy ở dưới chỉ có tác dụng
-- khi role đã có grant trên bảng; thiếu grant thì API trả 42501).
grant select, insert, update, delete on public.flashcard_progress to anon;
grant select, insert, update, delete on public.flashcard_reviews  to anon;
grant select, insert, update, delete on public.flashcard_settings to anon;
grant usage, select on sequence public.flashcard_reviews_id_seq to anon;

drop policy if exists "anon read flashcard_progress" on public.flashcard_progress;
create policy "anon read flashcard_progress" on public.flashcard_progress
  for select to anon using (true);

drop policy if exists "anon write flashcard_progress" on public.flashcard_progress;
create policy "anon write flashcard_progress" on public.flashcard_progress
  for all to anon using (true) with check (true);

drop policy if exists "anon read flashcard_reviews" on public.flashcard_reviews;
create policy "anon read flashcard_reviews" on public.flashcard_reviews
  for select to anon using (true);

drop policy if exists "anon write flashcard_reviews" on public.flashcard_reviews;
create policy "anon write flashcard_reviews" on public.flashcard_reviews
  for all to anon using (true) with check (true);

drop policy if exists "anon read flashcard_settings" on public.flashcard_settings;
create policy "anon read flashcard_settings" on public.flashcard_settings
  for select to anon using (true);

drop policy if exists "anon write flashcard_settings" on public.flashcard_settings;
create policy "anon write flashcard_settings" on public.flashcard_settings
  for all to anon using (true) with check (true);
