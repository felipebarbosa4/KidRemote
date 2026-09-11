import test from 'node:test';
import assert from 'node:assert/strict';
import { countAcceptanceCriteria } from '../validate-acceptance.mjs';

const rows = marks => marks.map((mark, i) => '- [' + mark + '] AC-' + (i + 1) + ': criterion').join('\n');
test('unchecked criteria count', () => assert.equal(countAcceptanceCriteria(rows([' ',' ',' ',' ',' '])), 5));
test('completed criteria remain part of the contract', () => assert.equal(countAcceptanceCriteria(rows(['x','x','x','x','x'])), 5));
test('partial AC-1–4 completion preserves seven-criterion contract', () => assert.equal(countAcceptanceCriteria(rows(['x','x','x','x',' ',' ',' '])), 7));
test('fewer or malformed criteria cannot satisfy five-criterion minimum', () => {
  assert.equal(countAcceptanceCriteria(rows(['x',' '])), 2);
  assert.equal(countAcceptanceCriteria('- [z] AC-1: invalid\n- [x] AC-junk\nprose AC-2:'), 0);
});
