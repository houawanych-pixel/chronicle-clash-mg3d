'use strict';
// Durable JSON store for one family world. Writes go to a temp file that is
// fsync'd and renamed over the old one, so a crash or restart mid-write
// leaves either the old state or the new one, never half a file.
const fs = require('fs');
const path = require('path');
const { emptyState, SCHEMA } = require('./rules');

function load(file) {
  if (!fs.existsSync(file)) return emptyState();
  const d = JSON.parse(fs.readFileSync(file, 'utf8'));
  if ((d.schema || 0) > SCHEMA) throw new Error(`state file ${file} is schema ${d.schema}; this server knows ${SCHEMA}`);
  return Object.assign(emptyState(), d, { schema: SCHEMA });
}

function save(file, state) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = file + '.tmp';
  const fd = fs.openSync(tmp, 'w');
  fs.writeSync(fd, JSON.stringify(state));
  fs.fsyncSync(fd);
  fs.closeSync(fd);
  fs.renameSync(tmp, file);
}

module.exports = { load, save };
