import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

// Routing lint only. No subprocess, network, database, or device operation.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(resolve(root, path), 'utf8');
const current = 'docs/exec-plans/TASK-CONTRACT.md';
const routingUrl = 'https://github.com/felipebarbosa4/KidRemote/blob/kr-product-enforcement-integration/' + current + '#current-execution';

function localTarget(base, from, target) {
  assert.ok(!/^[a-z][a-z0-9+.-]*:/i.test(target), 'Expected a local evidence link');
  assert.ok(!isAbsolute(target) && !target.includes('\\'), 'Expected a relative repository path');
  const full = resolve(base, dirname(from), target.split('#')[0]);
  const rel = relative(base, full);
  assert.ok(rel && rel !== '..' && !rel.startsWith('../') && !rel.startsWith('..\\') && !isAbsolute(rel), 'Link escapes repository');
  return full;
}

function physicalRecordTarget(text) {
  const links = [...text.matchAll(/\[Latest physical record\]\(([^)]+)\)/g)];
  assert.equal(links.length, 1, 'Keep one explicit current physical-record pointer');
  assert.ok(links[0][1].endsWith('.json'), 'Use the structured source record');
  return links[0][1];
}

test('unit: resolves an in-repository parent-relative evidence link', () => {
  assert.equal(localTarget(root, current, '../test-plans/example.json'), resolve(root, 'docs/test-plans/example.json'));
});

test('unit: refuses external, absolute and escaping evidence targets', () => {
  for (const target of ['https://example.invalid/result.json', '/result.json', '../../../../result.json', '..\\result.json']) {
    assert.throws(() => localTarget(root, current, target));
  }
});

test('unit: refuses absent or ambiguous physical-record pointers', () => {
  const link = '[Latest physical record](../test-plans/example.json)';
  assert.equal(physicalRecordTarget(link), '../test-plans/example.json');
  assert.throws(() => physicalRecordTarget('No record'));
  assert.throws(() => physicalRecordTarget(link + '\n' + link));
  assert.throws(() => physicalRecordTarget('[Latest physical record](example.md)'));
});

test('repository: entry points route to the same current execution summary', () => {
  for (const path of ['AGENTS.md', 'README.md']) {
    assert.ok(read(path).includes(routingUrl), `${path}: missing current execution route`);
    assert.ok(!read(path).includes('continue the active KR-003 feasibility issue'), `${path}: stale unconditional scheduler`);
  }
  assert.ok(read(current).includes('## Current execution'));
  assert.ok(read(current).includes('## Verification routing'));
});

test('repository: current physical summary matches its linked immutable record', () => {
  const text = read(current);
  const record = JSON.parse(readFileSync(localTarget(root, current, physicalRecordTarget(text)), 'utf8'));
  for (const value of [record.attempt, record.source, record.observedResult?.primaryStatus,
    record.observedResult?.primaryReason, record.observedResult?.primaryCleanup]) {
    assert.equal(typeof value, 'string', 'Missing source evidence field');
    assert.ok(text.includes('`' + value + '`'), `Current summary disagrees with linked evidence: ${value}`);
  }
});

test('repository: decision history is unchanged while future decisions may append', () => {
  const ledger = readFileSync(resolve(root, 'docs/DECISIONS-LOG.md'));
  // Preserve the audited historical prefix, not a permanent ban on new decisions.
  assert.ok(ledger.length >= 48282, 'Decision history was truncated');
  const bytes = ledger.subarray(0, 48282);
  const sha = createHash('sha1').update('blob ' + bytes.length + '\0').update(bytes).digest('hex');
  assert.equal(sha, 'f8c845e9543511e2fb0b328c97380aaafa590eaf');
  assert.ok(read('docs/DECISIONS.md').includes('(DECISIONS-LOG.md)'));
});
