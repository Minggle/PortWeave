const fs = require('node:fs');
const path = require('node:path');

const artifactsByPlatform = {
  macos: {
    arm64: ['subscription-ports-macos-arm64', 'subscription-ports-macos-safe-mode'],
    amd64: ['subscription-ports-macos-amd64'],
  },
  windows: {amd64: ['subscription-ports-windows']},
};

function checkSize(core, paths, limit) {
  function size(file) {
    const stat = fs.lstatSync(file);
    if (stat.isFile()) return stat.size;
    if (stat.isDirectory()) {
      return fs.readdirSync(file).reduce((total, name) => total + size(path.join(file, name)), 0);
    }
    throw new Error(`Unsupported artifact file: ${file}`);
  }
  const bytes = paths.reduce((total, file) => total + size(file), 0);
  if (bytes === 0 || bytes > limit) {
    throw new Error(`Artifact payload is ${bytes} bytes; expected 1–${limit} bytes (safe mode included).`);
  }
  core.info(`Artifact payload: ${bytes} / ${limit} bytes.`);
}

module.exports = async ({github, context, core, platform, arch, phase, paths}) => {
  const groups = artifactsByPlatform[platform];
  if (!groups || !['prepare', 'upload', 'finish'].includes(phase)) {
    throw new Error('Expected a ports platform and a prepare, upload or finish phase.');
  }
  if (`${context.repo.owner}/${context.repo.repo}` !== 'Minggle/PortWeave') {
    throw new Error('Artifact cleanup is restricted to Minggle/PortWeave.');
  }
  if (phase === 'upload') {
    if (!groups[arch]) throw new Error('Unsupported artifact architecture.');
    // ARM64 includes the optional debug ZIP; Windows ships both portable ZIP and Inno Setup EXE.
    const limit =
      platform === 'macos' && arch === 'arm64'
        ? 250_000_000
        : platform === 'windows'
          ? 200_000_000
          : 100_000_000;
    checkSize(core, paths, limit);
  }
  const actions = github.rest.actions;
  const repo = context.repo;
  const current = (await actions.getWorkflowRun({...repo, run_id: context.runId})).data;
  if (current.path !== `.github/workflows/ports-${platform}.yaml`) {
    throw new Error('Artifact cleanup must run from its owning ports workflow.');
  }
  const names = new Set(Object.values(groups).flat());
  const artifacts = (await github.paginate(actions.listArtifactsForRepo, {...repo, per_page: 100}))
    .filter((artifact) => names.has(artifact.name));
  const runs = new Map([[context.runId, current]]);
  for (const artifact of artifacts) {
    const id = artifact.workflow_run?.id;
    if (!id || runs.has(id)) continue;
    try {
      runs.set(id, (await actions.getWorkflowRun({...repo, run_id: id})).data);
    } catch (error) {
      if (error.status !== 404) throw error;
      runs.set(id, null);
    }
  }
  const owns = (run) => run && run.workflow_id === current.workflow_id && run.path === current.path;
  const others = [...runs.values()].filter((run) => owns(run) && run.id !== current.id);
  if (phase !== 'finish') {
    if (others.some((run) => run.status !== 'completed')) {
      throw new Error('Another run still owns platform artifacts; wait for it to finish before retrying.');
    }
    if (others.some((run) => run.run_number > current.run_number)) {
      throw new Error('A newer run already has platform artifacts; rerun the latest workflow instead.');
    }
  }
  const latest = Math.max(current.run_number, ...others
    .filter((run) => run.status === 'completed')
    .map((run) => run.run_number));
  const uploadNames = new Set(groups[arch] || []);
  let deleted = 0;
  // Snapshot all pages before deleting: removals otherwise shift subsequent pages.
  for (const artifact of artifacts) {
    const run = runs.get(artifact.workflow_run?.id);
    if (!owns(run)) continue;
    const isCurrent = run.id === current.id;
    if (!isCurrent && run.status !== 'completed') continue;
    if (phase === 'finish' && run.run_number >= latest) continue;
    if (phase === 'upload' && !uploadNames.has(artifact.name)) continue;
    try {
      await actions.deleteArtifact({...repo, artifact_id: artifact.id});
      core.info(`Deleted ${artifact.name} (${artifact.id}) from run ${run.id}.`);
      deleted++;
    } catch (error) {
      if (error.status !== 404) throw error;
    }
  }
  core.info(`${phase}: deleted ${deleted} scoped artifact(s).`);
};
