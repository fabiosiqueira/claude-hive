---
description: "Gera design system completo — paleta, tipografia, componentes, layouts."
---

# /design-system — Design System Generator

Você está gerando o design system para o projeto atual.

## Contexto

Antes de começar, leia:
1. O PRD ou plano existente em `docs/plans/` (se houver)
2. O `CLAUDE.md` do projeto para entender stack e constraints
3. Qualquer spec de design existente em `docs/design-spec.md`

## Processo

### 1. Definir Fundamentos

Pergunte ao usuário (se não especificado no plano):
- **Mood/estilo**: moderno, minimalista, bold, corporativo, playful?
- **Cores primárias**: alguma preferência ou marca existente?
- **Público-alvo**: quem usa isso?

### 2. Gerar Design Tokens

Crie os seguintes tokens:

```
Paleta:
- Primary (com shades 50-950)
- Secondary
- Accent
- Neutral (grays)
- Semantic: success, warning, error, info

Tipografia:
- Font family (heading + body)
- Scale (xs, sm, base, lg, xl, 2xl, 3xl)
- Line heights e letter spacing

Espaçamento:
- Scale baseada em 4px (1=4px, 2=8px, 3=12px, 4=16px...)

Bordas:
- Border radius scale
- Border widths

Sombras:
- sm, md, lg, xl
```

### 3. Mapear Componentes

Com base no plano/PRD, liste todos os componentes necessários e mapeie para shadcn/ui:

```
Para cada componente:
- Nome
- Componente shadcn correspondente (ou custom)
- Variantes necessárias
- Estados (default, hover, active, disabled, error)
```

### 4. Definir Layouts

Para cada página/tela do projeto:
- Layout grid (colunas, breakpoints)
- Hierarquia de componentes
- Responsividade (mobile-first)

### 5. Salvar Spec

Salve tudo em `docs/design-spec.md` com este formato:

```markdown
# Design System — [Nome do Projeto]

## Tokens
[paleta, tipografia, espaçamento, bordas, sombras]

## Componentes
[lista com variantes e estados]

## Layouts
[layouts por página]

## Tailwind Config
[extensões necessárias para tailwind.config.ts]
```

### 6. Gerar Tailwind Config

Crie ou atualize `tailwind.config.ts` com os tokens definidos.

### 7. Gate

O design system está completo quando:
- [ ] `docs/design-spec.md` existe com todos os tokens
- [ ] Componentes mapeados para shadcn/ui
- [ ] Layouts definidos para todas as páginas do plano
- [ ] `tailwind.config.ts` atualizado com tokens customizados

Apresente o resultado ao usuário e peça aprovação antes de prosseguir.
