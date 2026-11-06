const core = require('@actions/core');
const exec = require('@actions/exec');

const github = require('@actions/github');

const validateBranchName = ({ branchName }) => { /^[a-zA-Z0-9_\-\.\/]+$/.test(branchName) };
const validateDirectoryName = ({ dirName }) => { /^[a-zA-Z0-9_\-\/]+$/.test(dirName) };

async function run() {
  const baseBranch = core.getInput('base-branch', { required: true });
  const targetBranch = core.getInput('target-branch', { required: true });
  const ghToken = core.getInput('gh-token', { required: true });
  const workingDir = core.getInput('working-directory', { required: true });
  const debug = core.getInput('debug');

  const commonExecOpts = {
    cwd: workingDir
  };

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

  await exec.exec('npm', ['update'], { ...commonExecOpts });
  const gitStatus = await exec.getExecOutput('git status -s package*.json', [], { ...commonExecOpts });

  if (gitStatus.stdout.length > 0) {
    core.info('[js-dependency-update]: There are uppdates available for the following files:');
    core.info(gitStatus.stdout);

    await exec.exec(`git config --global user.name "github-automation"`);
    await exec.exec(`git config --global user.email "github-automation@noreply.github.com"`);
    await exec.exec(`git checkout -b ${targetBranch}`, [], { ...commonExecOpts });

    await exec.exec(`git add package*.json package-lock.json`, [], { ...commonExecOpts });
    await exec.exec(`git commit -m "chore: Update JS dependencies"`, [], { ...commonExecOpts });
    await exec.exec(`git push origin ${targetBranch} --force`, [], { ...commonExecOpts });

    const octokit = github.getOctokit(ghToken);
    try {
      await octokit.rest.pulls.create({
        owner: github.context.repo.owner,
        repo: github.context.repo.repo,
        title: `Update JS dependencies from ${targetBranch} to ${baseBranch}`,
        head: targetBranch,
        base: baseBranch,
        body: 'This pull request updates JS dependencies from the target branch to the base branch.'
      });
    } catch (error) {
      core.error(`Error creating pull request: ${error}`);
      core.error(error)
      core.setFailed(`Failed to create pull request: ${error.message}`);
    }

    core.info(`[js-dependency-update]: Pull request created from ${targetBranch} to ${baseBranch}`);


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
[Done] 4. If there are modified files:
  4.1 Add and commit files to the target-branch
  4.2 Create a PR to the base-branch using the octokit API
[Done] 5. Otherwise, conclude the custom action
*/
  core.info("I'm custom JS action'");
}

run();