-- 词冼 CiXian · Cloudflare D1 初始化脚本
-- 依据 functions/[[path]].js 中的实际 SQL 反推
-- 用法：wrangler d1 execute cixian --remote --file=./schema.sql

CREATE TABLE IF NOT EXISTS users (
  id         TEXT PRIMARY KEY,
  sync_code  TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS progress (
  user_id    TEXT PRIMARY KEY,
  data       TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS user_books (
  user_id     TEXT NOT NULL,
  book_id     TEXT NOT NULL,
  selected_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, book_id)
);

CREATE INDEX IF NOT EXISTS idx_users_sync_code ON users(sync_code);
CREATE INDEX IF NOT EXISTS idx_user_books_user ON user_books(user_id);
