# nauka-github-actions
Kurs github actions

## Docker action runner

The `17 - 3 - Custom Actions - Docker` workflow uses the GitHub-hosted
`ubuntu-latest` runner, which includes Docker. No local Docker installation
is required. Windows runners cannot run Docker container actions, even with
`shell: bash`.

The Docker action uses `ENTRYPOINT` to run `/app/main.py`; the URL, trial
count and delay are passed as script arguments, not as the container command.
The Python script currently only prints `Hello, Docker!` and does not yet
check the URL or implement retries.
