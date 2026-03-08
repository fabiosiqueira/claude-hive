# VoltAgent Circle v1 — Agents (Referência Histórica)

> Arquivo de referência. A v1 usava 8 agentes em série. A v2 substituiu por Superpowers + extensões Circle.
> Mantido para consulta sobre o modelo mental original.

## Pipeline v1
Orquestrador → Planejador → Designer → Devs (paralelo) → QA → Validação UI/UX → Segurança → Deploy

## Agentes

### 01 - Orquestrador (Dispatcher)
- Modelo sugerido: Opus 4.6
- Gerenciava fluxo do círculo, decidia próximo agente + modelo

### 02 - Planejador Estratégico
- Modelo sugerido: Opus 4.6
- PRD, roadmap, épicos, tarefas, hipóteses testáveis
- Skills referenciadas: prd-development, create-prd, roadmap-planning, sprint-plan

### 03 - Designer UI/UX
- Modelo sugerido: Opus 4.6 ou Sonnet
- Designs, componentes shadcn, brand guidelines, acessibilidade
- Skills referenciadas: frontend-design, canvas-design, theme-factory, shadcn-ui

### 04 - Dev Frontend
- Modelo sugerido: Sonnet
- React/Next.js + Tailwind + shadcn

### 05 - Dev Backend
- Modelo sugerido: Sonnet
- APIs, banco de dados, lógica de negócio

### 06 - QA & Testes
- Modelo sugerido: Haiku + Sonnet
- Testes unitários, E2E com Playwright, property-based testing
- Skills referenciadas: playwright-skill, property-based-testing

### 07 - Validação UI/UX
- Modelo sugerido: Sonnet
- Cliques reais, navegação, formulários, acessibilidade

### 08 - Segurança & Revisão Final
- Modelo sugerido: Sonnet
- Code review, security audit, compliance

## Por que foi substituído
- Roteamento de modelos não é possível no Claude Code (1 modelo por sessão)
- "ENCAMINHANDO PARA: [agente]" era decorativo — Claude Code não lê e spawna
- Confiança < 85% não é mensurável
- 8 handoffs fragmentavam o contexto desnecessariamente
