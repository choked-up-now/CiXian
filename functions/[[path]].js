/**
 * 词冼 CiXian 后端 API（Cloudflare Pages Functions 版本）
 * 接口：
 *   POST /register          注册新用户
 *   POST /bind              用同步码恢复账号
 *   POST /sync              上传进度
 *   GET  /sync?sync_code=xx 下载进度
 *
 * 注意：非 API 路径会通过 next() 交还给 Pages 静态资源处理。
 */

export async function onRequest(context) {
  const { request, env, next } = context;

  // CORS 预检
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() });
  }

  const url = new URL(request.url);
  const path = url.pathname;

  // 只处理 API 路径，其他请求（首页、JS、CSS、图片等）交还给 Pages
  const isApiPath = path === '/register' ||
                    path === '/bind' ||
                    path === '/sync';

  if (!isApiPath) {
    return next();
  }

  try {
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
    return json({ error: 'Not found' }, 404);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
}

// 注册
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

// 用同步码恢复账号
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

// 上传进度
async function handleSyncUpload(request, env) {
  const body = await request.json();
  const syncCode = (body.sync_code || '').toString().trim().toUpperCase();
  const data = body.data;

  if (!syncCode || !data) return json({ error: '参数不完整' }, 400);

  const user = await env.DB
    .prepare('SELECT id FROM users WHERE sync_code = ?')
    .bind(syncCode)
    .first();

  if (!user) return json({ error: '同步码无效' }, 404);

  const now = Date.now();
  const dataStr = JSON.stringify(data);

  await env.DB
    .prepare(
      `INSERT INTO progress (user_id, data, updated_at) VALUES (?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`
    )
    .bind(user.id, dataStr, now)
    .run();

  return json({ ok: true, updated_at: now });
}

// 下载进度
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

// ============ 工具函数 ============

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
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}