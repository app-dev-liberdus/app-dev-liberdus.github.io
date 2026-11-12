# Development web client

This repository hosts the client at `https://app-dev.liberdus.com/`.
Client files are copied to the repository root, without `dev` or `test` folders.

Keep a `web-client-v2` checkout beside this repository. With Bash, Git, `tar`,
and `rsync` installed, run this when ready to update the client:

```bash
./update-dev-client.sh
```

The script copies the source checkout's current `HEAD` commit. It excludes
untracked files, staged and unstaged changes, development files, and patterns
in the committed `.gitignore`. Commit source changes before updating this site.

No client files need to be prepared beforehand. The first run replaces the
placeholder `index.html` and copies the client assets, including the source
commit's `network.js`. Each run increments the client version letter and
refreshes `version.html`. The local `network.js_dev` file is left unchanged.

The script preserves `CNAME`, this README, itself, and existing files absent
from the source. It does not modify the source checkout, commit, push, or publish.
Review the resulting changes before committing and publishing.

To copy a local branch instead of the source checkout's current `HEAD`, and to
install that branch's `network.js`, run:

```bash
./update-dev-client-branch.sh codex/1883-near-send-qr
```

The branch must already exist locally in the sibling `web-client-v2` checkout.
This command also installs that branch's `network.js` and leaves `network.js_dev`
unchanged.
