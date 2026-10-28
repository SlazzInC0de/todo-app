// In-memory store: used by unit tests and when DB_HOST is not set,
// so the container can run on its own in Stage 1 without a database.
function createMemoryStore() {
  const todos = new Map();
  let nextId = 1;

  return {
    async init() {},
    async ping() {},
    async close() {},
    async list() {
      return [...todos.values()].sort((a, b) => a.id - b.id);
    },
    async create(title) {
      const todo = { id: nextId++, title, done: false, created_at: new Date().toISOString() };
      todos.set(todo.id, todo);
      return todo;
    },
    async setDone(id, done) {
      const todo = todos.get(id);
      if (!todo) return null;
      todo.done = done;
      return todo;
    },
    async remove(id) {
      return todos.delete(id);
    },
  };
}

module.exports = { createMemoryStore };
