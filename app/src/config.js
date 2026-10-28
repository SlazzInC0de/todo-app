// All configuration comes from environment variables (12-factor style),
// so the same image runs unchanged on a laptop, in Compose and in Kubernetes.
module.exports = {
  port: Number(process.env.PORT || 3000),
  version: process.env.APP_VERSION || 'dev',
  logLevel: process.env.LOG_LEVEL || 'info',
  db: {
    host: process.env.DB_HOST || '',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || 'todo',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'todo',
  },
};
