# claude-docker
Claude Code docker image to sandbox CC and only give access to relevant code. Includes some common tools that Claude likes to use.

## Getting Started

Mount your code to `/workspace`. Mount `.claude`, and `.claude.json` to maintain settings and sessions between launches.

```
$ docker build -t claude-code:latest .
$ docker run -it \
    -v $PWD:/workspace \
    -v $PWD/.claude:/home/devops/.claude \
    -v $PWD/.claude.json:/home/devops/.claude.json \
    claude-code:latest
```