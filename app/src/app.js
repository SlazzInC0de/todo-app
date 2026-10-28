const path = require('node:path');
const express = require('express');
const { register, metricsMiddleware } = require('./metrics');
const logger = require('./logger');

const ID_PATTERN = /^\d+$/;

function createApp({ store, version = 'dev' }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '10kb' }));
  app.use(metricsMiddleware);

  // --- operational endpoints -------------------------------------------
  // Liveness: is the process alive? (never checks dependencies)
  app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));

  // Readiness: can this instance serve traffic right now? (checks the DB)
  app.get('/readyz', async (_req, res) => {
    try {
      await store.ping();
      res.json({ status: 'ready' });
    } catch (err) {
      logger.warn('readiness check failed', { error: err.message });
      res.status(503).json({ status: 'database unavailable' });
    }
  });

  app.get('/version', (_req, res) => res.json({ version }));

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  // --- API -------------------------------------------------------------
  app.get('/api/todos', async (_req, res) => {
    res.json(await store.list());
  });

  app.post('/api/todos', async (req, res) => {
    const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
    if (!title || title.length > 200) {
      return res.status(400).json({ error: 'title is required (1-200 characters)' });
    }
    res.status(201).json(await store.create(title));
  });

  app.patch('/api/todos/:id', async (req, res) => {
    if (!ID_PATTERN.test(req.params.id) || typeof req.body?.done !== 'boolean') {
      return res.status(400).json({ error: 'numeric id and boolean "done" are required' });
    }
    const todo = await store.setDone(Number(req.params.id), req.body.done);
    if (!todo) return res.status(404).json({ error: 'not found' });
    res.json(todo);
  });

  app.delete('/api/todos/:id', async (req, res) => {
    if (!ID_PATTERN.test(req.params.id)) {
      return res.status(400).json({ error: 'numeric id is required' });
    }
    const removed = await store.remove(Number(req.params.id));
    if (!removed) return res.status(404).json({ error: 'not found' });
    res.status(204).end();
  });

  // --- web UI ----------------------------------------------------------
  app.use(express.static(path.join(__dirname, '..', 'public')));

  app.use((_req, res) => res.status(404).json({ error: 'not found' }));

  app.use((err, _req, res, _next) => {
    logger.error('unhandled error', { error: err.message });
    res.status(500).json({ error: 'internal error' });
  });

  return app;
}

module.exports = { createApp };
