const core = require('@actions/core');
const exec = require('@actions/exec');

const validateBranchName = ({ branchName }) => { /^[a-zA-Z0-9_\-\.\/]+$/.test(branchName) };
const validateDirectoryName = ({ dirName }) => { /^[a-zA-Z0-9_\-\/]+$/.test(dirName) };

async function run() {
  const baseBranch = core.getInput('base-branch');
  const targetBranch = core.getInput('target-branch');
  const workingDir = core.getInput('working-directory');
  const ghToken = core.getInput('gh-token');
  const debug = core.getInput('debug');

  core.setSecret(ghToken);
  if (debug === 'true') {
    core.info(`Base branch: ${baseBranch}`);
    core.info(`Target branch: ${targetBranch}`);
    core.info(`Working directory: ${workingDir}`);

    if (validateBranchName({ branchName: baseBranch })) {
      core.setFailed(`Base branch name is valid. Should include only characters a-z, A-Z, 0-9, _, -, ., /`);
      return;
    }
    if (validateBranchName({ branchName: targetBranch })) {
      core.setFailed(`Target branch name is valid. Should include only characters a-z, A-Z, 0-9, _, -, ., /`);
      return;
    }
    if (validateDirectoryName({ dirName: workingDir })) {
      core.setFailed(`Working directory name is valid. Should include only characters a-z, A-Z, 0-9, _, -, /`);
      return;
    }
  }

  core.info(`[js-dependency-update]: base branch: ${baseBranch}`);
  core.info(`[js-dependency-update]: target branch: ${targetBranch}`);
  core.info(`[js-dependency-update]: working directory: ${workingDir}`);

  await exec.exec('npm', ['update'], { cwd: workingDir });
  const gitStatus = await exec.getExecOutput('git status -s package*.json', [], { cwd: workingDir });

  if (gitStatus.stdout.length > 0) {
    core.info('[js-dependency-update]: There are uppdates available for the following files:');
    core.info(gitStatus.stdout);
  } else {
    core.info('[js-dependency-update]: No updates available for package*.json files in this time.');
  }
  core.info('[js-dependency-update]: Finished checking for updates.');
  core.info('[js-dependency-update]: Action completed.');
  core.info('[js-dependency-update]: Exiting action.');

  /*
[Done]  1. Parse inputs:
   1.1 base-branch from which to check for updates
   1.2 target-branch to use to create the PR
   1.3 Github Token for authentication purposes (to create PRs)
   1.4 Working directory for which to check for dependencies
[Done]  2. Execute the npm update command within the working directory
[Done]  3. Check whether there are modified package*.json files
4. If there are modified files:
   4.1 Add and commit files to the target-branch
   4.2 Create a PR to the base-branch using the octokit API
5. Otherwise, conclude the custom action
*/
  core.info("I'm custom JS action'");
}

run();