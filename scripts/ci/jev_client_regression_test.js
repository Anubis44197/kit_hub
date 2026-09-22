const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.TYPESAFE_API_KEY = 'synthetic-test-key';
const writeFileSync = fs.writeFileSync;
fs.writeFileSync = () => {};
const client = require(path.resolve(__dirname, '..', 'typesafe_jev_client.js'));
const uniqueText = () => 'Synthetic Jev regression ' + Date.now() + ' ' + Math.random();

(async () => {
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      model: 'mock',
      answers: {
        decision: { choice: 'BLOCKED', confidence: 0.99 },
        quality_score: { score: 0.2 },
        has_critical_issue: { noul: 0.9 }
      }
    })
  });
  const blocked = await client.judgeAgentDecision(uniqueText(), 'create');
  assert.equal(blocked.rawChoice, 'BLOCKED');
  assert.equal(blocked.verdict, 'BLOCKED');
  assert.equal(blocked.isFallback, false);

  global.fetch = async () => { throw new Error('synthetic timeout'); };
  const unavailable = await client.checkExportGate(uniqueText().repeat(30));
  assert.equal(unavailable.isFallback, true);
  assert.equal(unavailable.approved, false);
  assert.equal(unavailable.reviewRequired, true);
  assert.equal(unavailable.readyProbability, null);
  console.log('[jev-client-regression] PASS blocked precedence; export fallback requires review');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => {
  fs.writeFileSync = writeFileSync;
});
