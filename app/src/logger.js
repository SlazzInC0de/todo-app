// Minimal structured (JSON) logger: one line per event, easy to search in
// `docker logs`, `kubectl logs` or any log platform.
const levels = { debug: 10, info: 20, warn: 30, error: 40 };
const threshold = levels[process.env.LOG_LEVEL] ?? levels.info;

function log(level, msg, fields = {}) {
  if (levels[level] < threshold) return;
  const line = JSON.stringify({ time: new Date().toISOString(), level, msg, ...fields });
  (level === 'error' ? console.error : console.log)(line);
}

module.exports = {
  debug: (msg, f) => log('debug', msg, f),
  info: (msg, f) => log('info', msg, f),
  warn: (msg, f) => log('warn', msg, f),
  error: (msg, f) => log('error', msg, f),
};
