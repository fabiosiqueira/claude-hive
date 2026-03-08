# Changelog

## [2.0.0] - 2026-03-08

### Changed
- Reescrita completa do VoltAgent Circle sobre o framework Superpowers v4.3.1
- CLAUDE.MD reescrito com arquitetura v2, override de context bloat, e quality gates
- README.md reescrito com nova arquitetura e documentação

### Added
- `/circle` — pipeline completo (brainstorm → plan → design → execute → validate → security → ship)
- `/design-system` — geração de design tokens, componentes shadcn, layouts
- `/validate-ux` — validação UX real via Playwright MCP
- `/security-review` — audit OWASP Top 10 com classificação de severidade
- `/ship` — deploy com versão semver, changelog, commit, push, PR
- `docs/references/` — referência histórica da v1

### Removed
- `AGENTS/` (8 agentes em série) — substituído por Superpowers + extensões Circle
- `SKILLS/` (links para repos) — substituído por skills executáveis reais
- `EXAMPLES/` — substituído pelo pipeline `/circle`
