import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import {test} from 'node:test';
import assert from 'node:assert/strict';
const source = readFileSync(new URL('../lib/managers/js_api/tap_regions_script.dart', import.meta.url), 'utf8').split("r'''")[1].split("''';")[0];
function setup({viewport = true, answer = true} = {}) {
  const calls = [];
  const visualViewport = viewport ? Object.assign(new EventTarget(), {scale: 1.5, offsetLeft: 0, offsetTop: 0}) : undefined;
  const context = {window: {visualViewport}, call: async (method, params) => { calls.push([method, JSON.parse(JSON.stringify(params))]); return answer; }};
  runInNewContext(source + '\nthis.set = setScreensaverTapRegions;', context);
  return {calls, visualViewport, set: context.set};
}
const box = {left: 1, top: 2, width: 3, height: 4};
test('regions go out with the visual viewport they were measured in', async () => {
  const {calls, set} = setup();
  assert.equal(await set([box]), true);
  assert.deepEqual(calls, [['setScreensaverTapRegions', {rects: [box], viewport: {scale: 1.5, offsetLeft: 0, offsetTop: 0}}]]);
});
test('a pinch or scroll of the visual viewport sends the regions again', async () => {
  const {calls, visualViewport, set} = setup();
  await set([box]);
  visualViewport.offsetTop = 40;
  visualViewport.dispatchEvent(new Event('scroll'));
  visualViewport.scale = 2;
  visualViewport.dispatchEvent(new Event('resize'));
  assert.deepEqual(calls.slice(1), [
    ['setScreensaverTapRegions', {rects: [box], viewport: {scale: 1.5, offsetLeft: 0, offsetTop: 40}}],
    ['setScreensaverTapRegions', {rects: [box], viewport: {scale: 2, offsetLeft: 0, offsetTop: 40}}],
  ]);
});
test('cleared or refused regions are not sent again', async () => {
  const cleared = setup();
  await cleared.set([box]);
  await cleared.set([]);
  cleared.visualViewport.dispatchEvent(new Event('scroll'));
  assert.equal(cleared.calls.length, 2);
  const refused = setup({answer: false});
  await refused.set([box]);
  refused.visualViewport.dispatchEvent(new Event('scroll'));
  assert.equal(refused.calls.length, 1);
});
test('without a visual viewport the regions go out unscaled', async () => {
  const {calls, set} = setup({viewport: false});
  await set([box]);
  assert.deepEqual(calls, [['setScreensaverTapRegions', {rects: [box], viewport: null}]]);
});
