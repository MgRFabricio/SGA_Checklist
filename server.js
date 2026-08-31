const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const { Pool } = require("pg");

const root = __dirname;
const port = Number(process.env.PORT || 3000);
const pool = new Pool({
  host: process.env.POSTGRES_HOST || "localhost",
  port: Number(process.env.POSTGRES_PORT || 5432),
  database: process.env.POSTGRES_DB || "sga_checklist",
  user: process.env.POSTGRES_USER || "sga",
  password: process.env.POSTGRES_PASSWORD || "sga_local_dev"
});

const roleNames = {
  "Responsável pelo ambiente": "Responsavel pelo ambiente",
  Manutenção: "Manutencao",
  "Consulta/Auditoria": "Consulta/Auditoria"
};

function sendJson(response, status, body) {
  response.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(body));
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    request.on("data", chunk => { body += chunk; });
    request.on("end", () => {
      try { resolve(body ? JSON.parse(body) : {}); } catch { reject(new Error("JSON inválido")); }
    });
    request.on("error", reject);
  });
}

function publicUser(row) {
  return { id: row.id, name: row.name, email: row.email, role: row.role, status: row.active ? "Ativo" : "Inativo", lastLoginAt: row.last_login_at };
}

async function api(request, response, pathname) {
  if (pathname === "/api/health" && request.method === "GET") {
    await pool.query("SELECT 1");
    return sendJson(response, 200, { status: "ok", database: "connected" });
  }

  if (pathname === "/api/users" && request.method === "GET") {
    const result = await pool.query(`SELECT u.id, u.name, u.email, u.active, u.last_login_at, r.name AS role
      FROM users u JOIN roles r ON r.id = u.role_id ORDER BY u.name`);
    return sendJson(response, 200, result.rows.map(publicUser));
  }

  if (pathname === "/api/users" && request.method === "POST") {
    const body = await readBody(request);
    if (!body.name || !body.email || !body.password || !body.role) return sendJson(response, 400, { error: "name, email, password e role são obrigatórios" });
    if (body.password.length < 6) return sendJson(response, 400, { error: "A senha deve ter pelo menos 6 caracteres" });
    const role = roleNames[body.role] || body.role;
    const result = await pool.query(`INSERT INTO users (role_id, name, email, password_hash, active)
      VALUES ((SELECT id FROM roles WHERE name = $1), $2, lower($3), crypt($4, gen_salt('bf')), $5)
      RETURNING id, name, email, active, last_login_at, (SELECT name FROM roles WHERE id = role_id) AS role`,
      [role, body.name.trim(), body.email.trim(), body.password, body.status === "Ativo"]);
    return sendJson(response, 201, publicUser(result.rows[0]));
  }

  return sendJson(response, 404, { error: "Rota não encontrada" });
}

function serveStatic(request, response, pathname) {
  const requested = pathname === "/" ? "/index.html" : pathname;
  const filePath = path.resolve(root, `.${requested}`);
  if (!filePath.startsWith(root) || !fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) return sendJson(response, 404, { error: "Arquivo não encontrado" });
  const contentTypes = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8" };
  response.writeHead(200, { "Content-Type": contentTypes[path.extname(filePath)] || "application/octet-stream" });
  fs.createReadStream(filePath).pipe(response);
}

const server = http.createServer(async (request, response) => {
  const pathname = new URL(request.url, `http://${request.headers.host}`).pathname;
  try {
    if (pathname.startsWith("/api/")) await api(request, response, pathname);
    else if (request.method === "GET") serveStatic(request, response, pathname);
    else sendJson(response, 405, { error: "Método não permitido" });
  } catch (error) {
    console.error(error);
    sendJson(response, error.code === "23505" ? 409 : 500, { error: error.message });
  }
});

server.listen(port, () => console.log(`SGA-Checklist: http://localhost:${port}`));

process.on("SIGINT", async () => { await pool.end(); server.close(() => process.exit(0)); });
