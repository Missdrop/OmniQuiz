const fs = require('node:fs');
const path = require('node:path');

const assets = [
  'OmniQuiz-android-arm64-v8a.apk', 'OmniQuiz-android-armeabi-v7a.apk', 'OmniQuiz-android-x86_64.apk',
  'OmniQuiz-linux-x64.tar.gz',
  'OmniQuiz-windows-x64.zip',
  'OmniQuiz-windows-x64.msi',
  'OmniQuiz-macos.tar.gz',
  'OmniQuiz-macos.dmg',
  'OmniQuiz-ios-unsigned.tar.gz',
];

async function optional(request) {
  try { return (await request()).data; }
  catch (error) { if (error.status === 404) return null; throw error; }
}

module.exports = async function publish({ github, context, core, nightly, directory = 'dist' }) {
  const repo = context.repo;
  const tag = nightly ? 'nightly' : context.ref.replace(/^refs\/tags\//, '');
  if (!nightly && (!context.ref.startsWith('refs/tags/') || tag === 'nightly')) {
    throw new Error('A non-reserved release tag is required.');
  }
  // Validate the complete set before modifying any existing release.
  const files = assets.map(name => ({ name, data: fs.readFileSync(path.join(directory, name)) }));
  if (files.some(file => !file.data.length)) throw new Error('Empty release asset.');

  if (nightly) {
    const head = await github.rest.git.getRef({ ...repo, ref: 'heads/main' });
    if (head.data.object.sha !== context.sha) {
      core.notice('Skipping an outdated build; main has advanced.');
      return;
    }
  }
  let release = await optional(() => github.rest.repos.getReleaseByTag({ ...repo, tag }));
  if (release && nightly && !release.prerelease) {
    throw new Error('The nightly tag belongs to a stable release; refusing to overwrite it.');
  }
  if (release && !nightly && !release.draft) {
    core.notice('This tag is already published; keeping its assets unchanged.');
    return;
  }
  const body = [
    nightly ? 'Latest successful main build. Assets are replaced in place.' : `OmniQuiz ${tag}`,
    '', `Commit: ${context.sha}`,
    `Build: https://github.com/${repo.owner}/${repo.repo}/actions/runs/${context.runId}`,
    '', 'Android APKs use the fixed OmniQuiz release signing identity.',
    'Windows: MSI installer or portable ZIP. The installer is not code-signed.',
    'macOS: open the DMG and drag OmniQuiz to Applications. It is not notarized.',
    'The unsigned iOS app requires signing before installation.',
    'Application version comes from pubspec.yaml; update it before tagging a version.',
  ].join('\n');
  if (!release) {
    release = (await github.rest.repos.createRelease({
      ...repo, tag_name: tag, target_commitish: context.sha,
      name: nightly ? 'Nightly' : tag, body, draft: true,
      prerelease: nightly, make_latest: 'false',
    })).data;
  }
  const existing = await github.paginate(github.rest.repos.listReleaseAssets, {
    ...repo, release_id: release.id, per_page: 100,
  });
  // GitHub provides each asset's SHA-256 digest through the Releases API.
  for (const old of existing.filter(asset => asset.name === 'SHA256SUMS')) {
    await github.rest.repos.deleteReleaseAsset({ ...repo, asset_id: old.id });
  }
  for (const file of files) {
    const old = existing.find(asset => asset.name === file.name);
    if (old) await github.rest.repos.deleteReleaseAsset({ ...repo, asset_id: old.id });
    await github.rest.repos.uploadReleaseAsset({
      ...repo, release_id: release.id, name: file.name, data: file.data,
      headers: { 'content-type': 'application/octet-stream', 'content-length': file.data.length },
    });
  }
  if (nightly) {
    const ref = await optional(() => github.rest.git.getRef({ ...repo, ref: 'tags/nightly' }));
    if (ref) await github.rest.git.updateRef({ ...repo, ref: 'tags/nightly', sha: context.sha, force: true });
    else await github.rest.git.createRef({ ...repo, ref: 'refs/tags/nightly', sha: context.sha });
  }
  await github.rest.repos.updateRelease({
    ...repo, release_id: release.id, name: nightly ? 'Nightly' : tag,
    body, draft: false, prerelease: nightly, make_latest: nightly ? 'false' : 'true',
  });
};
