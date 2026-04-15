Pinned build-time tools for skills-repo plugin sites.

## Setup

```sh
python3 -m venv tools/venv && ./tools/venv/bin/pip install -r tools/requirements.txt
```

## Verify

```sh
tools/venv/bin/zensical --version
```

CI should run the same pip install step before invoking any plugin justfile.
