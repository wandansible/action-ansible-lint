# GitHub Action: Lint Ansible

Lint ansible and only display annotations for new or edited files

## Environment variables

| Environment variable    | Default   | Description |
| ----------------------- | --------- | ----------- |
| `ANSIBLE_LINT_ARGS`     | `""`      | Arguments passed to `ansible-lint` |
| `VALIDATE_ALL_CODEBASE` | `"false"` | Whether to show annotations for all files in the repository or just new/edited files (in reference to `DEFAULT_BRANCH`). Make sure to set `fetch-depth: 0` with `actions/checkout` |
| `DEFAULT_BRANCH`        | `"main"`  | The default branch of the repository |

## Sample usage

```yaml
---
name: Lint checks

on:
  push:
    branches-ignore:
      - main
  pull_request:
    branches:
      - main

jobs:
  ansible-lint:
    name: Ansible Lint
    runs-on: self-hosted
    steps:
      - name: Checkout repo
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Lint ansible
        uses: wanduow/action-ansible-lint@v1
```

With ansible-lint arguments:

```yaml
      - name: Lint ansible
        uses: wanduow/action-ansible-lint@v1
        env:
          ANSIBLE_LINT_ARGS: "-vv ansible-dir/"
```
