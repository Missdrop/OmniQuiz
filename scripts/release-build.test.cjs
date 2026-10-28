const { test } = require('node:test');
const assert = require('node:assert/strict');
const select = require('./release-build.cjs');

function fixture(runs, artifacts = [], updates = []) {
  let waits = 0;
  return {
    context: { repo: { owner: 'owner', repo: 'repo' }, sha: 'current' },
    core: { notice() {} },
    sleep: async () => { waits++; },
    github: {
      rest: { actions: {
        listWorkflowRuns: async () => ({ data: { workflow_runs: runs } }),
        listWorkflowRunArtifacts() {},
        getWorkflowRun: async () => ({ data: updates.shift() }),
      } },
      paginate: async () => artifacts,
    },
    waits: () => waits,
  };
}
const complete = { id: 7, head_sha: 'current', head_branch: 'main', status: 'completed', conclusion: 'success' };
const artifacts = ['android', 'ios', 'linux', 'macos', 'windows'].map(name => ({ name: `omniquiz-${name}`, expired: false }));

test('reuses only a successful exact-commit main run with every platform artifact', async () => {
  assert.equal(await select(fixture([complete], artifacts)), 7);
  assert.equal(await select(fixture([{ ...complete, head_sha: 'older' }], artifacts)), null);
  assert.equal(await select(fixture([{ ...complete, head_branch: 'dev' }], artifacts)), null);
});
test('waits for an in-progress main build without cancelling it or starting duplicate builds', async () => {
  const options = fixture([{ ...complete, status: 'in_progress', conclusion: null }], artifacts, [complete]);
  assert.equal(await select(options), 7);
  assert.equal(options.waits(), 1);
});
test('missing, skipped, expired, cancelled and failed builds require a fresh tag build', async () => {
  assert.equal(await select(fixture([])), null);
  assert.equal(await select(fixture([complete])), null);
  assert.equal(await select(fixture([complete], artifacts.map(a => ({ ...a, expired: true })))), null);
  for (const conclusion of ['failure', 'cancelled', 'timed_out', 'skipped']) {
    assert.equal(await select(fixture([{ ...complete, conclusion }], artifacts)), null);
  }
});
test('GitHub metadata failures are not mistaken for a missing build', async () => {
  const options = fixture([]);
  options.github.rest.actions.listWorkflowRuns = async () => { throw new Error('Forbidden'); };
  await assert.rejects(select(options), /Forbidden/);
});
