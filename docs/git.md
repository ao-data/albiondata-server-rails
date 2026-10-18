# Git workflow

- `main` is the protected branch. Claude may commit and create branches, but must **never** merge
  into `main` directly. The user merges to `main` manually.
- Claude must **never** push to GitHub (no `git push`, including feature branches). The user
  handles all pushing.
- Do the rest of git normally: create feature branches, stage changes, write commits, open local
  branches for review, etc. — just stop short of the merge-to-main and push steps above.
