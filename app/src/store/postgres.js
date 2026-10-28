const { Pool } = require('pg');
const logger = require('../logger');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function createPostgresStore(db) {
  const pool = new Pool({ ...db, max: 10, connectionTimeoutMillis: 3000 });

  // Without this handler, a database restart kills idle pooled connections,
  // the pool emits an unhandled 'error' event and the whole process crashes.
  // With it, the pool drops the dead connection and opens a new one later.
  pool.on('error', (err) => {
    logger.warn('idle database connection lost', { error: err.message });
  });

  return {
    // Retry on startup: in Compose and Kubernetes the database may start
    // after the API. Failing fast here would just cause a restart loop.
    async init({ retries = 30, delayMs = 2000 } = {}) {
      for (let attempt = 1; ; attempt++) {
        try {
          await pool.query(`
            CREATE TABLE IF NOT EXISTS todos (
              id         SERIAL PRIMARY KEY,
              title      TEXT NOT NULL,
              done       BOOLEAN NOT NULL DEFAULT FALSE,
              created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )`);
          logger.info('database ready', { host: db.host, attempt });
          return;
        } catch (err) {
          if (attempt >= retries) throw err;
          logger.warn('database not ready, retrying', { attempt, error: err.message });
          await sleep(delayMs);
        }
      }
    },
    async ping() {
      await pool.query('SELECT 1');
    },
    async close() {
      await pool.end();
    },
    async list() {
      const { rows } = await pool.query('SELECT id, title, done, created_at FROM todos ORDER BY id');
      return rows;
    },
    async create(title) {
      const { rows } = await pool.query(
        'INSERT INTO todos (title) VALUES ($1) RETURNING id, title, done, created_at',
        [title],
      );
      return rows[0];
    },
    async setDone(id, done) {
      const { rows } = await pool.query(
        'UPDATE todos SET done = $2 WHERE id = $1 RETURNING id, title, done, created_at',
        [id, done],
      );
      return rows[0] ?? null;
    },
    async remove(id) {
      const { rowCount } = await pool.query('DELETE FROM todos WHERE id = $1', [id]);
      return rowCount > 0;
    },
  };
}

module.exports = { createPostgresStore };
