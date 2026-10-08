import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import assert from 'node:assert/strict';
const source = readFileSync('lib/auth/jwxt_page.dart', 'utf8');
const script = source.match(/const _extractTables = r'''([\s\S]*?)''';/)[1];
const cell = (text, rowSpan = 1, colSpan = 1) => ({innerText: text, rowSpan, colSpan});
const row = (...cells) => ({cells});
const table = {rows: [
  row(cell('节次'), ...['一','二','三','四','五','六','日'].map(d => cell('星期' + d))),
  row(cell('第 1–2 节'), cell('数据结构\n张老师\n主楼302\n1-16周'), ...Array.from({length: 6}, () => cell(''))),
  row(cell('第3节'), cell(''), cell('操作系统', 2), ...Array.from({length: 5}, () => cell(''))),
  row(cell('第4节'), cell(''), ...Array.from({length: 5}, () => cell(''))),
]};
const document = {querySelectorAll: selector => selector === 'table' ? [table] : []};
const result = JSON.parse(runInNewContext(script, {document}));
assert.deepEqual(result.map(c => [c.weekday, c.startPeriod, c.endPeriod]), [[1,1,2],[2,3,4]]);
assert.equal(result[0].text.split('\n')[0], '数据结构');
const frameDoc = document;
const parent = {querySelectorAll: selector => selector === 'iframe,frame' ? [{contentDocument: frameDoc}] : []};
assert.equal(JSON.parse(runInNewContext(script, {document: parent})).length, 2);
assert.equal(JSON.parse(runInNewContext(script, {document: {querySelectorAll: () => []}})).length, 0);
console.log('WebView extraction passed: spaced period labels, ranges, row spans, same-origin frames and empty pages.');
