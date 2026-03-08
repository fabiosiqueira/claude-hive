---
description: "Valida UX com testes reais — navegação, cliques, formulários, acessibilidade."
---

# /validate-ux — Validação UX com Playwright

Você está validando a experiência do usuário do projeto com testes reais.

## Pré-requisitos

1. O projeto deve estar rodando localmente (dev server ativo)
2. Playwright MCP deve estar configurado e acessível
3. Design spec deve existir em `docs/design-spec.md` (referência para validação)

Se o dev server não estiver rodando, inicie-o antes de prosseguir.

## Processo de Validação

### 1. Inventário de Interações

Leia o plano em `docs/plans/` e o design spec em `docs/design-spec.md`.
Liste todas as interações que precisam ser testadas:

```
Para cada página:
- [ ] Navegação: página carrega corretamente
- [ ] Links: todos os links internos funcionam
- [ ] Botões: todos os botões respondem ao clique
- [ ] Formulários: campos aceitam input, validação funciona, submit funciona
- [ ] Responsividade: layout correto em mobile (375px) e desktop (1280px)
- [ ] Acessibilidade: tab navigation, labels, contraste
```

### 2. Executar Testes via Playwright MCP

Para cada interação no inventário, use o Playwright MCP para:

**Navegação:**
- Navegar para a URL
- Tirar screenshot
- Verificar que elementos esperados estão visíveis

**Formulários:**
- Clicar em campos
- Preencher com dados válidos
- Submeter
- Verificar resposta de sucesso
- Repetir com dados inválidos
- Verificar mensagens de erro

**Responsividade:**
- Definir viewport para mobile (375x812)
- Tirar screenshot
- Verificar layout não quebrado
- Repetir para desktop (1280x800)

**Acessibilidade básica:**
- Verificar que todos os inputs têm labels
- Verificar que botões têm texto acessível
- Verificar contraste mínimo (se possível via ferramenta)

### 3. Documentar Resultados

Para cada teste:
- PASS ou FAIL
- Se FAIL: screenshot + descrição do problema

### 4. Gate

A validação UX passa quando:
- [ ] Todas as páginas carregam sem erros
- [ ] Todos os formulários funcionam (submit + validação)
- [ ] Todos os botões/links respondem
- [ ] Layout não quebra em mobile e desktop
- [ ] Nenhum problema crítico de acessibilidade

Se houver falhas, liste-as e pergunte ao usuário:
- "Encontrei N problemas de UX. Quer que eu corrija agora ou documente para fix posterior?"

Se corrigir, volte ao passo 2 para re-validar após as correções.
