// RED metrics (Rate, Errors, Duration) for Prometheus.
const client = require('prom-client');

const register = client.register;
client.collectDefaultMetrics({ register });

const httpDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
});

// Label by the matched route pattern (/api/todos/:id), never the raw URL
// (/api/todos/1, /api/todos/2, ...), which would create unbounded series.
function routeLabel(req, res) {
  if (req.route) return req.baseUrl + req.route.path;
  return res.statusCode === 404 ? 'not_found' : 'static';
}

function metricsMiddleware(req, res, next) {
  const end = httpDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: routeLabel(req, res), status: res.statusCode });
  });
  next();
}

module.exports = { register, metricsMiddleware };
