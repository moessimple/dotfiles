# Installing the tools

The gate is raised against the production dependencies as they are, so installing a tool must not move them. Never use `--with-all-dependencies` (`-W`): it upgrades production packages, up to the framework itself. A package without a lock file follows [package.md](package.md) instead of steps 1 and 4.

1. Record the production packages: `composer show --locked --no-dev --format=json`.
2. Choose versions that fit the project: Larastan for the installed Laravel, `driftingly/rector-laravel` for the installed Rector, Pest plugins of the installed Pest major.
3. Add the packages without updating, then update only them:

   ```bash
   composer require --dev {packages} --no-update
   composer update {packages} --with-dependencies --minimal-changes
   ```

4. Compare the production packages with step 1.
   - **No change:** continue.
   - **Any change, patch level included:** try older minor versions of the tool, newest first, with `--dry-run`, and take the first one that leaves every production package unchanged. If none does, it is a blocker: restore `composer.json` and `composer.lock` with `git checkout`, run `composer install`, and report which package the tool would move.

Commit the installation on its own, before any tool changes code.
