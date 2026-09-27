// Copyright 2026 choked-up-now
// SPDX-License-Identifier: Apache-2.0

/**
 * 词冼 CiXian 后端 API
 *
 * 认证 / 同步：
 *   POST /register
 *   POST /bind
 *   POST /sync
 *   GET  /sync?sync_code=xx
 *
 * 词书市场：
 *   GET    /wordbooks                      词书列表
 *   GET    /wordbooks/:id                  词书内容
 *   GET    /user/books?sync_code=xx        我选中的词书
 *   POST   /user/books                     添加选中
 *   DELETE /user/books/:id                 移除选中
 */

const WORDBOOK_REPO = 'choked-up-now/CiXianWordBook';
const WORDBOOK_BRANCH = 'main';
const ATOMGIT_RAW_BASE =
  `https://api.atomgit.com/api/v5/repos/${WORDBOOK_REPO}/raw`;

export async function onRequest(context) {
  const { request, env, next } = context;

  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() });
  }

  const url = new URL(request.url);
  const path = url.pathname;

  try {
    // 认证
    if (path === '/register' && request.method === 'POST') {
      return await handleRegister(env);
    }
    if (path === '/bind' && request.method === 'POST') {
      return await handleBind(request, env);
    }
    if (path === '/sync' && request.method === 'POST') {
      return await handleSyncUpload(request, env);
    }
    if (path === '/sync' && request.method === 'GET') {
      return await handleSyncDownload(url, env);
    }

    // 词书列表 / 内容
    if (path === '/wordbooks' && request.method === 'GET') {
      return await handleWordbookList();
    }
    if (path.startsWith('/wordbooks/') && request.method === 'GET') {
      const id = path.substring('/wordbooks/'.length);
      return await handleWordbookDetail(id);
    }

    // 我的词书（选中）
    if (path === '/user/books' && request.method === 'GET') {
      return await handleUserBooksList(url, env);
    }
    if (path === '/user/books' && request.method === 'POST') {
      return await handleUserBooksAdd(request, env);
    }
    if (path.startsWith('/user/books/') && request.method === 'DELETE') {
      const id = path.substring('/user/books/'.length);
      return await handleUserBooksRemove(request, env, id);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }

  return next();
}

// ============ 认证 / 同步 ============

async function handleRegister(env) {
  const userId = generateUserId();
  const syncCode = generateSyncCode();
  const now = Date.now();

  await env.DB
    .prepare('INSERT INTO users (id, sync_code, created_at) VALUES (?, ?, ?)')
    .bind(userId, syncCode, now)
    .run();

  return json({ user_id: userId, sync_code: syncCode });
}

async function handleBind(request, env) {
  const body = await request.json();
  const syncCode = (body.sync_code || '').toString().trim().toUpperCase();
  if (!syncCode) return json({ error: '同步码不能为空' }, 400);

  const row = await env.DB
    .prepare('SELECT id FROM users WHERE sync_code = ?')
    .bind(syncCode)
    .first();

  if (!row) return json({ error: '同步码无效' }, 404);
  return json({ user_id: row.id });
}

async function handleSyncUpload(request, env) {
  const body = await request.json();
  const syncCode = (body.sync_code || '').toString().trim().toUpperCase();
  const data = body.data;

  if (!syncCode || !data) return json({ error: '参数不完整' }, 400);

  const user = await findUserByCode(env, syncCode);
  if (!user) return json({ error: '同步码无效' }, 404);

  const now = Date.now();
  await env.DB
    .prepare(
      `INSERT INTO progress (user_id, data, updated_at) VALUES (?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`
    )
    .bind(user.id, JSON.stringify(data), now)
    .run();

  return json({ ok: true, updated_at: now });
}

async function handleSyncDownload(url, env) {
  const syncCode = (url.searchParams.get('sync_code') || '').trim().toUpperCase();
  if (!syncCode) return json({ error: '同步码不能为空' }, 400);

  const row = await env.DB
    .prepare(
      `SELECT p.data, p.updated_at FROM progress p
       JOIN users u ON u.id = p.user_id
       WHERE u.sync_code = ?`
    )
    .bind(syncCode)
    .first();

  if (!row) return json({ data: null, updated_at: 0 });
  return json({ data: JSON.parse(row.data), updated_at: row.updated_at });
}

// ============ 词书代理 ============

async function handleWordbookList() {
  const targetUrl =
    `${ATOMGIT_RAW_BASE}/wordbooks/index.json?ref=${WORDBOOK_BRANCH}`;
  const response = await fetch(targetUrl);
  if (!response.ok) {
    return json({ error: `获取词书列表失败 (${response.status})` }, 502);
  }
  const text = await response.text();
  return new Response(text, {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...corsHeaders(),
    },
  });
}

async function handleWordbookDetail(bookId) {
  if (!/^[a-zA-Z0-9_-]+$/.test(bookId)) {
    return json({ error: 'Invalid book id' }, 400);
  }
  const targetUrl =
    `${ATOMGIT_RAW_BASE}/wordbooks/${bookId}.json?ref=${WORDBOOK_BRANCH}`;
  const response = await fetch(targetUrl);
  if (!response.ok) {
    return json({ error: `词书不存在 (${response.status})` }, 502);
  }
  const text = await response.text();
  return new Response(text, {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...corsHeaders(),
    },
  });
}

// ============ 我的词书 ============

async function handleUserBooksList(url, env) {
  const syncCode = (url.searchParams.get('sync_code') || '').trim().toUpperCase();
  if (!syncCode) return json({ error: '同步码不能为空' }, 400);

  const user = await findUserByCode(env, syncCode);
  if (!user) return json({ error: '同步码无效' }, 404);

  const rows = await env.DB
    .prepare('SELECT book_id, selected_at FROM user_books WHERE user_id = ? ORDER BY selected_at DESC')
    .bind(user.id)
    .all();

  return json({
    books: (rows.results || []).map((r) => ({
      book_id: r.book_id,
      selected_at: r.selected_at,
    })),
  });
}

async function handleUserBooksAdd(request, env) {
  const body = await request.json();
  const syncCode = (body.sync_code || '').toString().trim().toUpperCase();
  const bookId = (body.book_id || '').toString().trim();

  if (!syncCode || !bookId) return json({ error: '参数不完整' }, 400);
  if (!/^[a-zA-Z0-9_-]+$/.test(bookId)) {
    return json({ error: 'Invalid book id' }, 400);
  }

  const user = await findUserByCode(env, syncCode);
  if (!user) return json({ error: '同步码无效' }, 404);

  await env.DB
    .prepare(
      `INSERT OR IGNORE INTO user_books (user_id, book_id, selected_at)
       VALUES (?, ?, ?)`
    )
    .bind(user.id, bookId, Date.now())
    .run();

  return json({ ok: true });
}

async function handleUserBooksRemove(request, env, bookId) {
  const url = new URL(request.url);
  const syncCode = (url.searchParams.get('sync_code') || '').trim().toUpperCase();
  if (!syncCode) return json({ error: '同步码不能为空' }, 400);

  const user = await findUserByCode(env, syncCode);
  if (!user) return json({ error: '同步码无效' }, 404);

  await env.DB
    .prepare('DELETE FROM user_books WHERE user_id = ? AND book_id = ?')
    .bind(user.id, bookId)
    .run();

  return json({ ok: true });
}

// ============ 工具 ============

async function findUserByCode(env, syncCode) {
  return await env.DB
    .prepare('SELECT id FROM users WHERE sync_code = ?')
    .bind(syncCode)
    .first();
}

function generateUserId() {
  const random = Math.random().toString(36).substring(2, 10);
  return `u_${Date.now()}_${random}`;
}

function generateSyncCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const pick = () => chars[Math.floor(Math.random() * chars.length)];
  const group = () => pick() + pick() + pick();
  return `${group()}-${group()}-${group()}`;
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...corsHeaders(),
    },
  });
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}