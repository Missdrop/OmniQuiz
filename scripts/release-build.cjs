// Reuse a matching main build when a tag is pushed after its merge has started Nightly.
const required = ['android', 'ios', 'linux', 'macos', 'windows'].map(name => `omniquiz-${name}`);

module.exports = async function releaseBuild({ github, context, core, sleep = ms => new Promise(resolve => setTimeout(resolve, ms)) }) {
  const repo = context.repo;
  const { data } = await github.rest.actions.listWorkflowRuns({
    ...repo, workflow_id: 'prerelease.yml', head_sha: context.sha, event: 'push', per_page: 100,
  });
  let run = data.workflow_runs.find(item => item.head_sha === context.sha &&
    item.head_branch === 'main' && !['cancelled', 'failure', 'timed_out'].includes(item.conclusion));
  if (!run) return null;
  // The main preflight may skip a commit that already has a release tag. In that case
  // it produces no artifacts, and the tag workflow builds normally instead.
  for (let attempt = 0; attempt < 120; attempt++) {
    if (run.status === 'completed') {
      if (run.conclusion !== 'success') return null;
      const artifacts = await github.paginate(github.rest.actions.listWorkflowRunArtifacts, { ...repo, run_id: run.id, per_page: 100 });
      if (!required.every(name => artifacts.some(item => item.name === name && !item.expired))) return null;
      core.notice(`Reusing tested release packages from main run ${run.id}.`);
      return run.id;
    }
    await sleep(15000);
    run = (await github.rest.actions.getWorkflowRun({ ...repo, run_id: run.id })).data;
  }
  throw new Error('Matching main build is still running. Retry the tag workflow after it completes.');
};
