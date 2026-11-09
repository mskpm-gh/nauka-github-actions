const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

async function runAction({ inputs = {}, stdout = ' M package-lock.json\n', existing = [], apiError, execError } = {}) {
  const calls = [];
  const messages = [];
  const failures = [];
  const outputs = [];
  const values = {
    'base-branch': 'main',
    'head-branch': 'update-dependencies',
    'gh-token': 'test-token',
    'working-directory': '17-custom-actions/react-app',
    debug: 'false',
    ...inputs
  };
  const core = {
    getInput: (name) => values[name],
    setSecret: () => {},
    info: (message) => messages.push(message),
    error: () => {},
    setOutput: (name, value) => outputs.push({ name, value }),
    setFailed: (message) => failures.push(message)
  };
  const exec = {
    exec: async (command, args, options) => {
      calls.push({ command, args: Array.from(args), options });
      if (execError) throw execError;
      return 0;
    },
    getExecOutput: async (command, args, options) => {
      calls.push({ command, args: Array.from(args), options });
      return { exitCode: 0, stdout, stderr: '' };
    }
  };
  const pulls = {
    list: async (params) => {
      calls.push({ command: 'pulls.list', params });
      if (apiError !== undefined) throw apiError;
      return { data: existing };
    },
    create: async (params) => {
      calls.push({ command: 'pulls.create', params });
      return { data: { html_url: 'https://example.invalid/new-pr' } };
    }
  };
  const github = {
    context: { repo: { owner: 'test-owner', repo: 'test-repo' } },
    getOctokit: () => ({ rest: { pulls } })
  };
  const modules = { '@actions/core': core, '@actions/exec': exec, '@actions/github': github };
  await vm.runInNewContext(source, { require: (name) => modules[name], Error });
  return { calls, messages, failures, outputs };
}

test('updates the reusable branch and creates a PR with debug disabled', async () => {
  const result = await runAction();
  assert.deepEqual(result.failures, []);
  assert.deepEqual(result.outputs, [{ name: 'updates-available', value: true }]);
  assert(result.calls.some(({ command, args }) => command === 'git' && args.join(' ') === 'checkout -B update-dependencies'));
  assert(result.calls.some(({ command, args }) => command === 'git' && args.join(' ') === 'push origin update-dependencies --force'));
  assert(result.calls.filter(({ command }) => command === 'git' || command === 'npm')
    .every(({ options }) => options.cwd === '17-custom-actions/react-app'));
  assert(!result.calls.some(({ args = [] }) => args.includes('--global')));
  assert.equal(result.calls.find(({ command }) => command === 'pulls.list').params.head, 'test-owner:update-dependencies');
  assert.equal(result.calls.filter(({ command }) => command === 'pulls.create').length, 1);
  assert(result.messages.some((message) => message.includes('Pull request created:')));
  assert(!result.messages.some((message) => message.includes('[DEBUG]')));
});

test('reuses an existing open PR', async () => {
  const result = await runAction({ existing: [{ html_url: 'https://example.invalid/existing-pr' }] });
  assert.deepEqual(result.failures, []);
  assert.deepEqual(result.outputs, [{ name: 'updates-available', value: true }]);
  assert(!result.calls.some(({ command }) => command === 'pulls.create'));
  assert(result.messages.some((message) => message.includes('Pull request updated:')));
});

test('does not create a branch or PR without dependency updates', async () => {
  const result = await runAction({ stdout: '' });
  assert.deepEqual(result.failures, []);
  assert.deepEqual(result.outputs, [{ name: 'updates-available', value: false }]);
  assert(!result.calls.some(({ command, args = [] }) => command.startsWith('pulls.') || args.includes('checkout')));
  assert(result.messages.some((message) => message.includes('No updates available')));
});

for (const inputs of [
  { 'base-branch': 'bad branch' },
  { 'head-branch': 'bad;branch' },
  { 'working-directory': 'bad;directory' },
  { 'head-branch': 'main' }
]) {
  test(`rejects invalid inputs before running commands: ${JSON.stringify(inputs)}`, async () => {
    const result = await runAction({ inputs });
    assert.equal(result.failures.length, 1);
    assert.equal(result.calls.length, 0);
  });
}

test('reports Git errors explicitly', async () => {
  const result = await runAction({ execError: new Error('Invalid Git ref') });
  assert.deepEqual(result.failures, ['Invalid Git ref']);
  assert(!result.calls.some(({ command }) => command === 'npm'));
});

test('reports API denial without success messages', async () => {
  const result = await runAction({ apiError: Object.assign(new Error('Denied'), { status: 403 }) });
  assert.equal(result.failures.length, 1);
  assert(result.failures[0].includes('Allow GitHub Actions'));
  assert(!result.messages.some((message) => /Pull request (created|updated):|Action completed/.test(message)));
});

test('handles a null API error and enables debug logging', async () => {
  const result = await runAction({ apiError: null, inputs: { debug: 'true' } });
  assert.deepEqual(result.failures, ['Failed to create or update pull request: null']);
  assert(result.messages.some((message) => message.includes('[DEBUG]')));
});
