---
description: "Audit de segurança — OWASP Top 10, secrets, input validation, auth."
---

# /security-review — Security Audit

Você está realizando um audit de segurança no código do projeto.

## Processo

### 1. Escopo

Identifique os arquivos que precisam de review:
- Todos os arquivos modificados desde o último commit na branch principal (`git diff --name-only main...HEAD`)
- Se não houver branch separada, todos os arquivos do projeto (exceto node_modules, .next, dist)

### 2. Checklist OWASP Top 10

Revise o código contra cada categoria:

**A01 — Broken Access Control**
- [ ] Rotas protegidas verificam autenticação ANTES de lógica de negócio
- [ ] Autorização por recurso (não apenas "está logado")
- [ ] Sem IDOR (IDs previsíveis sem verificação de ownership)

**A02 — Cryptographic Failures**
- [ ] Secrets via env vars (nunca hardcoded)
- [ ] Sem `.env` com valores reais no git
- [ ] HTTPS em produção
- [ ] Passwords com hash (bcrypt/argon2), nunca plaintext

**A03 — Injection**
- [ ] SQL: Prisma parameterizado (sem `$queryRawUnsafe` com input dinâmico)
- [ ] XSS: sem `dangerouslySetInnerHTML` com input do usuário sem sanitização
- [ ] Command injection: sem `exec()` com input do usuário

**A04 — Insecure Design**
- [ ] Rate limiting em endpoints públicos
- [ ] Validação de input com schema (Zod/Yup)
- [ ] Fail-safe defaults

**A05 — Security Misconfiguration**
- [ ] CORS restritivo (não `*` em produção)
- [ ] Headers de segurança configurados
- [ ] Debug/verbose desabilitado em produção

**A06 — Vulnerable Components**
- [ ] `npm audit` sem CRITICAL/HIGH
- [ ] Dependências atualizadas

**A07 — Auth Failures**
- [ ] Session management segura
- [ ] Tokens com expiração
- [ ] Logout invalida session

**A08 — Data Integrity**
- [ ] Dados do usuário validados antes de persistir
- [ ] Sem deserialização de dados não confiáveis

**A09 — Logging & Monitoring**
- [ ] Sem secrets nos logs (passwords, tokens, API keys)
- [ ] Erros logados com contexto suficiente
- [ ] Ações críticas auditáveis

**A10 — SSRF**
- [ ] URLs de input do usuário validadas (não fazem fetch para IPs internos)

### 3. Executar Review

Use o subagent type `code-reviewer` do Agent tool para revisar os arquivos identificados.
Instrua o reviewer a focar nos pontos do checklist OWASP acima.

### 4. Verificações Automatizadas

Execute quando aplicável:
```bash
npm audit                    # vulnerabilidades em dependências
npx tsc --noEmit             # type safety (erros de tipo podem causar vulnerabilidades)
```

### 5. Classificar Issues

Para cada issue encontrada, classifique:
- **CRITICAL**: explorável imediatamente, causa dano real (secrets expostos, SQL injection)
- **HIGH**: explorável com algum esforço (XSS, IDOR, auth bypass)
- **MEDIUM**: defesa em profundidade (rate limiting ausente, headers faltando)
- **LOW**: best practice (logging melhorável, validação extra)

### 6. Gate

O security review passa quando:
- [ ] 0 issues CRITICAL
- [ ] 0 issues HIGH
- [ ] Issues MEDIUM documentadas (fix pode ser posterior)
- [ ] `npm audit` sem CRITICAL/HIGH

Se houver issues CRITICAL ou HIGH:
- Liste cada issue com: arquivo, linha, descrição, severidade, fix sugerido
- Pergunte: "Encontrei N issues de segurança que precisam de fix antes do deploy. Posso corrigir?"
- Corrija e re-execute o review para confirmar que foram resolvidas
