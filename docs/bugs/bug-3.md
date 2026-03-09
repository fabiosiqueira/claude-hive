# Hive Bug Report #3 — Workers não fazem commit antes de sinalizar conclusão

**Data:** 2026-03-08
**Run ID:** 20260308-171121
**Status: ✅ CORRIGIDO** — fix em v1.0.3: instrução de commit explícita adicionada ao template do worker

---

## Bug 3.1 — System prompt do worker não exige commit antes de HIVE_TASK_COMPLETE

**Onde ocorre:** Instrução do worker (step 5 do dispatching-workers skill)

**Sintoma:**
Worker escreve `HIVE_TASK_COMPLETE` no result file, sinaliza via `tmux wait-for -S`, mas
os arquivos criados/modificados ficam **não commitados** no worktree:

```
?? src/scripts/oos_eval.py
?? tests/test_oos_eval_script.py
 M src/scripts/feature_ablation.py
```

**Causa:** O system prompt do worker diz apenas:
> "When done, write your result file with HIVE_TASK_COMPLETE at the end"

Não há instrução para commitar as mudanças antes de sinalizar.

**Impacto:** O merge do worktree não captura o trabalho — o orchestrator precisa fazer
commit manual em cada worktree antes do merge.

**Workaround aplicado:**
```bash
# Para cada worktree após conclusão:
git -C .hive/worktrees/task-N add <files>
git -C .hive/worktrees/task-N commit -m "feat: <descrição>"
git merge hive/<run-id>/task-N --no-ff -m "merge: task-N"
```

**Correção sugerida:** Adicionar ao system prompt do worker, antes de "write your result file":
```
- Commit all your changes with a descriptive message before writing the result file
- Use: git add <files> && git commit -m "feat: <description>"
- Only then write HIVE_TASK_COMPLETE to the result file
```

---

## Impacto

Sem commit, o `worktree_merge` não captura nada — os arquivos ficam como untracked/modified
no worktree e se perdem na limpeza. O orchestrator fica responsável por identificar e
commitar manualmente o que devia ter sido feito pelo worker.
