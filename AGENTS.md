# Repository Guidelines

## Project Structure & Module Organization
- Rails 8 app rooted in `app/` (`controllers`, `models`, `views`, `jobs`, `services`, `javascript` for Stimulus+Turbo, and `assets` for Tailwind and image/fonts).
- Tests live in `test/` with `test/system` for browser flows and fixtures under `test/fixtures`.
- Config lives in `config/` (`queue.yml` and `recurring.yml` for Solid Queue, environment files in `config/environments/`). Database migrations are in `db/migrate`.
- Docs and deployment guides: see `docs/` and `DEPLOYMENT_GUIDE.md`. Docker workflows use `Dockerfile`, `docker-compose.yml`, and `docker.env.example`.

## Build, Test, and Development Commands
- Install deps: `bundle install` and `bin/rails javascript:install` only if front-end deps are missing.
- DB setup: `bin/rails db:migrate` and `bin/rails db:migrate SCHEMA=db/queue_schema.rb` (Solid Queue schema); seed with `bin/rails db:seed` if needed.
- Run dev server (with assets and jobs): `bin/dev`.
- Tests: `bin/rails test` for unit/integration; `bin/rails test:system` for system specs (requires browser driver).
- Lint/security: `bin/rubocop` for style/format; `bin/brakeman` for security checks.
- Background queue worker: `bin/rails solid_queue:start` (dev) or use Procfile via `bin/dev`.

## Coding Style & Naming Conventions
- Ruby style enforced by RuboCop (`.rubocop.yml`); use 2-space indentation, snake_case methods/variables, CamelCase classes/modules.
- Stimulus controllers follow `app/javascript/controllers/*_controller.js` naming; targets/actions use kebab-case in HTML.
- Prefer service objects in `app/services/` for non-trivial domain logic; keep controllers thin.
- Tailwind-first styling; avoid inline styles except small overrides.

## Testing Guidelines
- Framework: Rails Minitest. Name tests after the class/feature under test; system tests should mirror UI flows (e.g., `feeds_test.rb`, `articles_flow_test.rb`).
- Add coverage for new behaviors; update fixtures/factories when altering schemas.
- Run `bin/rails test` (and `bin/rails test:system` for UI changes) before opening a PR.

## Commit & Pull Request Guidelines
- Commit messages observed in history use short, imperative subjects (e.g., “Fix infinite scroll loading too many articles at once”). Follow that style; keep body focused on rationale when needed.
- For PRs, include: scope/purpose summary, linked issue (if any), test commands executed, screenshots/GIFs for UI changes, and notes on migrations or background job impacts.
- Keep changesets small and cohesive; flag any production config changes (queues, schedules, env vars) in the PR description.

## Security & Configuration Tips
- Do not commit secrets; copy `.env.example` or `docker.env.example` and keep keys (e.g., `RAILS_MASTER_KEY`, API tokens) local.
- Solid Queue schedules/queues: review `config/recurring.yml` and `config/queue.yml` when altering job timing or queues.
- Before deploying, ensure assets are compiled (`bin/rails assets:precompile`) and migrations run.***
