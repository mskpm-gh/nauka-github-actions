const core = require('@actions/core');
const exec = require('@actions/exec');

const github = require('@actions/github');

const validateBranchName = ({ branchName }) => /^[a-zA-Z0-9_\-\.\/]+$/.test(branchName);
const validateDirectoryName = ({ dirName }) => /^[a-zA-Z0-9_\-\/]+$/.test(dirName);

const setupLogger = ({ debug, prefix } = { debug: false, prefix: '' }) => ({
  debug: (message) => {
    if (debug) {
      core.info(`[DEBUG] ${prefix}${prefix ? ' : ' : ''}${message}`);
    }
  },
  info: (message) => {
    core.info(`${prefix}${prefix ? ' : ' : ''}${message}`);
  },
  error: (message) => {
    core.error(`${prefix}${prefix ? ' : ' : ''}${message}`);
  }
});


async function run() {
  const baseBranch = core.getInput('base-branch', { required: true });
  const headBranch = core.getInput('head-branch', { required: true });
  const ghToken = core.getInput('gh-token', { required: true });
  const workingDir = core.getInput('working-directory', { required: true });
  const debug = core.getInput('debug');
  const logger = setupLogger({ debug: debug === 'true', prefix: '[js-dependency-update]' });

  const commonExecOpts = {
    cwd: workingDir
  };

  const setupGit = async () => {
    await exec.exec('git', ['config', '--local', 'user.name', 'github-automation'], commonExecOpts);
    await exec.exec('git', ['config', '--local', 'user.email', 'github-automation@noreply.github.com'], commonExecOpts);
  };

  core.setSecret(ghToken);

  logger.debug(`Starting with base branch: ${baseBranch}, head branch: ${headBranch}, working directory: ${workingDir}`);

  if (!validateBranchName({ branchName: baseBranch })) {
    core.setFailed('Base branch name is invalid. Should include only characters a-z, A-Z, 0-9, _, -, ., /');
    return;
  }
  if (!validateBranchName({ branchName: headBranch })) {
    core.setFailed('Head branch name is invalid. Should include only characters a-z, A-Z, 0-9, _, -, ., /');
    return;
  }
  if (!validateDirectoryName({ dirName: workingDir })) {
    core.setFailed('Working directory name is invalid. Should include only characters a-z, A-Z, 0-9, _, -, /');
    return;
  }
  if (baseBranch === headBranch) {
    core.setFailed('Head branch must differ from base branch.');
    return;
  }
  await exec.exec('git', ['check-ref-format', '--branch', baseBranch], commonExecOpts);
  await exec.exec('git', ['check-ref-format', '--branch', headBranch], commonExecOpts);


  logger.debug(`Base branch: ${baseBranch}`);
  logger.debug(`Head branch: ${headBranch}`);
  logger.debug(`Working directory: ${workingDir}`);

  logger.debug(`Checking for package updates`);

  await exec.exec('npm', ['update'], { ...commonExecOpts });
  const gitStatus = await exec.getExecOutput('git', ['status', '--short', '--', 'package*.json'], commonExecOpts);

  if (gitStatus.stdout.length > 0) {
    logger.info('There are updates available for the following files:');
    logger.info(gitStatus.stdout);

    logger.debug('Setting up Git commit identity');
    await setupGit();

    logger.debug(`Committing changes to branch: ${headBranch}`);
    await exec.exec('git', ['checkout', '-B', headBranch], commonExecOpts);

    await exec.exec('git', ['add', '--', 'package*.json'], commonExecOpts);
    await exec.exec('git', ['commit', '-m', 'chore: Update JS dependencies'], commonExecOpts);
    await exec.exec('git', ['push', 'origin', headBranch, '--force'], commonExecOpts);

    logger.debug(`Fetching octokit API client for GitHub API interactions`);

    const octokit = github.getOctokit(ghToken);
    let pullRequest;
    try {
      logger.debug(`Checking for an open PR from ${headBranch} to ${baseBranch}`);
      const existingPullRequests = await octokit.rest.pulls.list({
        owner: github.context.repo.owner,
        repo: github.context.repo.repo,
        state: 'open',
        head: `${github.context.repo.owner}:${headBranch}`,
        base: baseBranch,
        per_page: 1
      });
      if (existingPullRequests.data.length > 0) {
        pullRequest = existingPullRequests.data[0];
        logger.info(`Pull request updated: ${pullRequest.html_url}`);
      } else {
        const response = await octokit.rest.pulls.create({
          owner: github.context.repo.owner,
          repo: github.context.repo.repo,
          title: `Update JS dependencies from ${headBranch} to ${baseBranch}`,
          head: headBranch,
          base: baseBranch,
          body: 'This pull request updates JS dependencies from the head branch to the base branch.'
        });
        pullRequest = response.data;
        logger.info(`Pull request created: ${pullRequest.html_url}`);
      }

    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error(`Failed to create or update pull request: ${message}`);
      if (error && error.status === 403) {
        core.setFailed(
          'GitHub denied pull request creation. Enable "Allow GitHub Actions to create and approve pull requests" in repository Settings > Actions > General, or use a PAT/GitHub App token with pull request permissions.'
        );
      } else {
        core.setFailed(`Failed to create or update pull request: ${message}`);
      }
      return;
    }

  } else {
    logger.info('No updates available for package*.json files at this time.');
  }
  logger.debug('Finished checking for updates.');
  logger.debug('Action completed.');
  logger.debug('Exiting action.');

}
run().catch((error) => {
  core.setFailed(error instanceof Error ? error.message : String(error));
});