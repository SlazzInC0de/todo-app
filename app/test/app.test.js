const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/store/memory');

const newApp = (store = createMemoryStore()) => createApp({ store, version: 'test-sha' });

describe('operational endpoints', () => {
  test('GET /healthz returns ok', async () => {
    const res = await request(newApp()).get('/healthz');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ok');
  });

  test('GET /readyz returns 503 when the database is down', async () => {
    const store = createMemoryStore();
    store.ping = async () => { throw new Error('connection refused'); };
    const res = await request(newApp(store)).get('/readyz');
    assert.equal(res.status, 503);
  });

  test('GET /version reports the build version', async () => {
    const res = await request(newApp()).get('/version');
    assert.equal(res.body.version, 'test-sha');
  });

  test('GET /metrics exposes the request histogram', async () => {
    const app = newApp();
    await request(app).get('/api/todos');
    const res = await request(app).get('/metrics');
    assert.equal(res.status, 200);
    assert.match(res.text, /http_request_duration_seconds_bucket/);
    assert.match(res.text, /route="\/api\/todos"/);
  });
});

describe('todo API', () => {
  test('create, list, complete and delete a todo', async () => {
    const app = newApp();

    const created = await request(app).post('/api/todos').send({ title: '  Write Dockerfile  ' });
    assert.equal(created.status, 201);
    assert.equal(created.body.title, 'Write Dockerfile');
    assert.equal(created.body.done, false);

    const list = await request(app).get('/api/todos');
    assert.equal(list.body.length, 1);

    const updated = await request(app).patch(`/api/todos/${created.body.id}`).send({ done: true });
    assert.equal(updated.status, 200);
    assert.equal(updated.body.done, true);

    const removed = await request(app).delete(`/api/todos/${created.body.id}`);
    assert.equal(removed.status, 204);

    const after = await request(app).get('/api/todos');
    assert.deepEqual(after.body, []);
  });

  test('rejects an empty title', async () => {
    const res = await request(newApp()).post('/api/todos').send({ title: '   ' });
    assert.equal(res.status, 400);
  });

  test('rejects a non-numeric id', async () => {
    const res = await request(newApp()).patch('/api/todos/abc').send({ done: true });
    assert.equal(res.status, 400);
  });

  test('returns 404 for a missing todo', async () => {
    const res = await request(newApp()).delete('/api/todos/999');
    assert.equal(res.status, 404);
  });

  test('serves the web UI', async () => {
    const res = await request(newApp()).get('/');
    assert.equal(res.status, 200);
    assert.match(res.text, /<title>Todo/);
  });
});
