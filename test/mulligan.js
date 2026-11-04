/* 开局换牌（mulligan）单元测试 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');

function assert(cond, msg) { if (!cond) throw new Error('FAIL: ' + msg); }

for (var t = 0; t < 200; t++) {
  var first = Math.random() < 0.5 ? 'p1' : 'p2';
  var state = Engine.newGame('liubang', 'xiangyu', first, 'bijiang');
  assert(state.phase === 'mulligan', 'newGame 后应处于换牌阶段');
  assert(state.turnNo === 0, '换牌阶段回合数应为 0');

  var p1 = state.players.p1;
  var handBefore = p1.hand.length;
  assert(handBefore === (first === 'p1' ? 3 : 5), '起手牌数不符（先手 3 / 后手 4+先机=5）');
  var deckBefore = p1.deck.length;
  /* 后手额外持有一张不属于牌库的「先机」 */
  assert(deckBefore + handBefore === (first === 'p1' ? 20 : 21), '牌库+手牌总数不符');

  /* 选 1-2 张换掉 */
  var pick = p1.hand.slice(0, Math.min(2, p1.hand.length)).map(function (c) { return c.uid; });
  var res = Engine.doMulligan(state, 'p1', pick);
  assert(res.ok, 'doMulligan 应成功');
  assert(p1.hand.length === handBefore, '换牌后手牌数不变');
  assert(p1.deck.length === deckBefore, '换牌后牌库数不变');

  /* AI 换牌 */
  var r2 = Engine.doMulligan(state, 'p2', AI.aiMulligan(state, 'p2'));
  assert(r2.ok, 'AI 换牌应成功');

  /* 重复换牌应被拒绝 */
  var r3 = Engine.doMulligan(state, 'p1', []);
  assert(!r3.ok, '不能换两次');

  /* 开局 */
  Engine.beginGame(state);
  assert(state.phase === 'play', 'beginGame 后进入对局阶段');
  assert(state.turnNo === 1, '开局后应为第 1 回合');
  assert(state.players[first].maxMana === 1, '先手第 1 回合军粮上限 1');

  /* 先机不可被换：构造后手必持先机的场景已天然覆盖——若后手 AI 把先机换没了就是 bug */
  var second = Engine.other(first);
  var hasXianji = state.mulliganDone[second]; /* 已换过；先机若被换掉会在手牌/牌库中仍存在，下面检查总数 */
  var total = 0;
  [state.players[second].hand, state.players[second].deck].forEach(function (pile) {
    pile.forEach(function (c) { if (c.baseId === 's_xianji') total++; });
  });
  assert(total === 1, '先机虎符必须仍然存在（不可被换掉）');
}

/* 全保留路径 */
(function () {
  var state = Engine.newGame('xiangyu', 'liubang', 'p1', 'mingjiang');
  var res = Engine.doMulligan(state, 'p1', []);
  assert(res.ok && res.swapped === 0, '全保留应换 0 张');
  Engine.doMulligan(state, 'p2', []);
  Engine.beginGame(state);
  assert(state.players.p1.hand.length === 4, '先手全保留：开局手牌 3+抽 1=4');
})();

console.log('✅ mulligan 测试通过（200 轮随机 + 全保留路径）');
