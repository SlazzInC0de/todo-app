const config = require('./config');
const logger = require('./logger');
const { createApp } = require('./app');
const { createMemoryStore } = require('./store/memory');
const { createPostgresStore } = require('./store/postgres');

async function main() {
  let store;
  if (config.db.host) {
    store = createPostgresStore(config.db);
  } else {
    logger.warn('DB_HOST not set: using in-memory store, data is lost on restart');
    store = createMemoryStore();
  }
  await store.init();

  const app = createApp({ store, version: config.version });
  const server = app.listen(config.port, () => {
    logger.info('todo-api listening', { port: config.port, version: config.version });
  });

  // Graceful shutdown: Kubernetes sends SIGTERM before killing a pod.
  // Stop accepting new connections, finish in-flight requests, then exit.
  const shutdown = (signal) => {
    logger.info('shutting down', { signal });
    server.close(async () => {
      await store.close();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  logger.error('failed to start', { error: err.message });
  process.exit(1);
});
