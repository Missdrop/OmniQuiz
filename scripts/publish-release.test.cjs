const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const publish = require('./publish-release.cjs');

function fixture(t, { nightly = true, existing = true, head = 'abc' } = {}) {
  fs.mkdirSync('.tooling', { recursive: true });
  const directory = fs.mkdtempSync('.tooling/release-test-');
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const names = ['OmniQuiz-android-arm64-v8a.apk', 'OmniQuiz-android-armeabi-v7a.apk', 'OmniQuiz-android-x86_64.apk', 'OmniQuiz-linux-x64.tar.gz',
    'OmniQuiz-windows-x64.zip', 'OmniQuiz-windows-x64.msi',
    'OmniQuiz-macos.tar.gz', 'OmniQuiz-macos.dmg', 'OmniQuiz-ios-unsigned.tar.gz'];
  for (const name of names) fs.writeFileSync(path.join(directory, name), name);
  const calls = [];
  const record = name => async args => { calls.push({ name, args }); return { data: { id: 7 } }; };
  const github = {
    rest: {
      git: {
        getRef: async args => ({ data: { object: { sha: head } } }),
        updateRef: record('updateRef'), createRef: record('createRef'),
      },
      repos: {
        getReleaseByTag: async () => {
          if (!existing) throw Object.assign(new Error('Missing'), { status: 404 });
          return { data: { id: 7, draft: false, prerelease: nightly } };
        },
        createRelease: record('createRelease'), updateRelease: record('updateRelease'),
        listReleaseAssets: () => {}, deleteReleaseAsset: record('deleteReleaseAsset'),
        uploadReleaseAsset: record('uploadReleaseAsset'),
      },
    },
    paginate: async () => existing ? [...names, 'SHA256SUMS'].map((name, id) => ({ name, id })) : [],
  };
  return {
    calls, options: { github, nightly, directory, core: { notice: () => {} },
      context: { repo: { owner: 'owner', repo: 'repo' }, ref: 'refs/tags/v0.1.0', sha: 'abc', runId: 1 } },
  };
}

test('nightly replaces ten assets on the same release without creating another', async t => {
  const { calls, options } = fixture(t);
  await publish(options);
  assert.equal(calls.filter(c => c.name === 'createRelease').length, 0);
  assert.equal(calls.filter(c => c.name === 'deleteReleaseAsset').length, 10);
  assert.equal(calls.filter(c => c.name === 'uploadReleaseAsset').length, 10);
  const update = calls.at(-1).args;
  assert.equal(update.release_id, 7);
  assert.equal(update.prerelease, true);
  assert.equal(update.make_latest, 'false');
});

test('first nightly creates one draft then publishes it', async t => {
  const { calls, options } = fixture(t, { existing: false });
  await publish(options);
  assert.equal(calls[0].args.tag_name, 'nightly');
  assert.equal(calls[0].args.draft, true);
  assert.equal(calls.at(-1).args.draft, false);
});

test('tag release uses the exact tag name and never moves its tag', async t => {
  const { calls, options } = fixture(t, { nightly: false, existing: false });
  await publish(options);
  assert.equal(calls[0].args.name, 'v0.1.0');
  assert.equal(calls.at(-1).args.name, 'v0.1.0');
  assert.equal(calls.at(-1).args.prerelease, false);
  assert.equal(calls.some(c => c.name === 'updateRef'), false);
});

test('old main builds and already-published stable tags cause no mutations', async t => {
  for (const settings of [{ head: 'newer' }, { nightly: false }]) {
    const { calls, options } = fixture(t, settings);
    await publish(options);
    assert.equal(calls.length, 0);
  }
});

test('incomplete artifacts and API failures do not create a release', async t => {
  const { calls, options } = fixture(t);
  fs.unlinkSync(path.join(options.directory, 'OmniQuiz-macos.tar.gz'));
  await assert.rejects(publish(options));
  assert.equal(calls.length, 0);
  fs.writeFileSync(path.join(options.directory, 'OmniQuiz-macos.tar.gz'), 'mac');
  options.github.rest.repos.getReleaseByTag = async () => {
    throw Object.assign(new Error('Forbidden'), { status: 403 });
  };
  await assert.rejects(publish(options), /Forbidden/);
  assert.equal(calls.length, 0);
});

test('missing desktop installers block publication before any release changes', async t => {
  for (const name of ['OmniQuiz-windows-x64.msi', 'OmniQuiz-macos.dmg']) {
    const { calls, options } = fixture(t);
    fs.unlinkSync(path.join(options.directory, name));
    await assert.rejects(publish(options));
    assert.equal(calls.length, 0);
  }
});
