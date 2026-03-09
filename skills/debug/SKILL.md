---
name: debug
description: "Diagnose a bug from error input, propose a fix plan, get approval, and execute"
---

# Hive Debug

Você recebeu um erro para diagnosticar e corrigir. Siga os passos em ordem.
Não escreva código antes de completar o diagnóstico e obter aprovação do usuário.

## Step 1: Coletar input

O usuário forneceu um ou mais dos seguintes:
- Descrição do erro em texto
- Stack trace / log de saída
- Imagem/screenshot (use `Read` para visualizar se fornecida como path)

Se a descrição for ambígua, faça **uma** pergunta objetiva antes de continuar.

## Step 2: Diagnóstico (STAR)

Leia os arquivos relevantes identificados no erro. Consulte `git log --oneline -10` e
`git log --oneline -10 -- <arquivo>` para identificar mudanças recentes.

Estruture o diagnóstico:

```
**Situação:** O que o erro diz / o que está acontecendo
**Tarefa:** O que deveria acontecer (comportamento esperado)
**Ação:** Causa raiz — qual código, linha ou lógica provoca a divergência
**Resultado:** O que precisa mudar para corrigir
```

**GATE:** Não avance sem identificar a causa raiz com um trecho de código específico.
"Algo neste módulo" não é suficiente.

## Step 3: Avaliar complexidade

Classifique o fix:

| Critério | Direto | Workers (hive-dispatch) |
|---|---|---|
| Arquivos afetados | ≤ 2 | 3+ |
| Causa raiz | Clara e isolada | Múltiplos módulos ou refactor |
| Dependências entre mudanças | Nenhuma | Tasks paralelizáveis independentes |

## Step 4: Propor plano de fix

Apresente ao usuário:

```
## Plano de fix

**Causa raiz:** <uma frase>
**Abordagem:** direto pelo orquestrador | workers paralelos

### Mudanças

| Arquivo | Mudança |
|---------|---------|
| `path/to/file.ext` | <descrição> |

### Teste de regressão
`tests/path/to/test.ext` — deve falhar antes do fix, passar depois
```

**GATE:** Aguarde confirmação explícita do usuário antes de qualquer mudança.

## Step 5: Executar o fix

### Fix direto (≤ 2 arquivos, causa clara)

Siga TDD:
1. Escreva o teste de regressão → confirme que **falha** com o erro original
2. Aplique o fix mínimo
3. Confirme que o teste **passa**
4. Commit: `fix: <descrição concisa>`

### Fix via workers (3+ arquivos ou complexo)

1. Salve o plano em `docs/plans/YYYY-MM-DD-debug-<descricao>.md`
2. Execute `/hive-dispatch` para rodar o plano com workers paralelos
3. Monitore via TaskCreate/TaskUpdate até conclusão

## Step 6: Verificar

Após o fix:

```bash
# Rode a suite de testes completa do projeto
```

Confirme:
- [ ] Teste de regressão passa
- [ ] Suite completa passa sem novas falhas
- [ ] O erro original não se reproduz mais

Reporte ao usuário: causa raiz, arquivo corrigido, teste adicionado.

## Princípios

- **Diagnóstico antes de código.** Nunca toque em um arquivo sem entender por quê.
- **Fix mínimo.** Corrija só o que causa o bug. Não refatore adjacências.
- **Teste de regressão obrigatório.** Todo fix tem um teste que teria pegado o bug.
- **Uma pergunta por vez.** Se precisar de mais contexto, pergunte um item por vez.
