---
description: "Security audit -- OWASP Top 10 checklist, secrets scan, input validation, dependency audit."
disable-model-invocation: true
---

# /security-review -- Security Audit (Phase 6)

You are performing a security audit on the project code. This is Phase 6 of the Hive pipeline, executed after UX validation and before the final ship.

## Process

### 1. Determine Scope

Identify files that need review:
- All files modified since the last commit on the main branch: `git diff --name-only main...HEAD`
- If no separate branch exists, all project source files (exclude `node_modules`, `.next`, `dist`, `.hive/`)

### 2. OWASP Top 10 Checklist

Review the scoped files against each category:

**A01 -- Broken Access Control**
- [ ] Protected routes verify authentication before business logic
- [ ] Authorization is per-resource, not just "is logged in"
- [ ] No IDOR via predictable IDs without ownership check

**A02 -- Cryptographic Failures**
- [ ] Secrets loaded from environment variables, never hardcoded
- [ ] No `.env` with real values committed to git
- [ ] HTTPS enforced in production
- [ ] Passwords hashed with bcrypt or argon2, never stored in plaintext

**A03 -- Injection**
- [ ] SQL: Prisma parameterized queries only (no `$queryRawUnsafe` with dynamic input)
- [ ] XSS: no `dangerouslySetInnerHTML` with unsanitized user input
- [ ] Command injection: no `exec()` with user-controlled strings

**A04 -- Insecure Design**
- [ ] Rate limiting on public endpoints
- [ ] Input validated with a schema library (Zod, Yup, or equivalent)
- [ ] Fail-safe defaults

**A05 -- Security Misconfiguration**
- [ ] CORS restricted to specific origins (not `*` in production)
- [ ] Security headers configured
- [ ] Debug/verbose mode disabled in production builds

**A06 -- Vulnerable Components**
- [ ] `npm audit` reports no CRITICAL or HIGH vulnerabilities
- [ ] Dependencies reasonably up to date

**A07 -- Authentication Failures**
- [ ] Secure session management
- [ ] Tokens have expiration
- [ ] Logout invalidates the session

**A08 -- Data Integrity**
- [ ] User data validated before persistence
- [ ] No deserialization of untrusted data

**A09 -- Logging & Monitoring**
- [ ] No secrets in logs (passwords, tokens, API keys)
- [ ] Errors logged with sufficient context
- [ ] Critical actions produce audit trail

**A10 -- SSRF**
- [ ] User-supplied URLs validated (no fetch to internal IPs)

### 3. Code Review

Use the Hive `agents/reviewer.md` agent (if available) or a subagent to review the scoped files with the OWASP checklist above as the review criteria. Focus the review on security, not style.

### 4. Automated Checks

Run where applicable:
```bash
npm audit                    # dependency vulnerabilities
npx tsc --noEmit             # type safety (type errors can create vulnerabilities)
```

### 5. Classify Issues

For every finding, assign a severity:
- **CRITICAL**: immediately exploitable, causes real harm (exposed secrets, SQL injection)
- **HIGH**: exploitable with moderate effort (XSS, IDOR, auth bypass)
- **MEDIUM**: defense-in-depth gaps (missing rate limiting, missing headers)
- **LOW**: best-practice improvements (better logging, extra validation)

### 6. Remediate Critical/High Issues

If CRITICAL or HIGH issues are found:
1. List each issue with: file, line, description, severity, suggested fix
2. Ask the user: "Found N security issues that must be fixed before shipping. Should I fix them now?"
3. If approved, apply fixes and re-run this review to confirm resolution

## Gate

The security review passes when:
- [ ] Zero CRITICAL issues
- [ ] Zero HIGH issues
- [ ] MEDIUM issues documented (fix can be deferred)
- [ ] `npm audit` reports no CRITICAL or HIGH vulnerabilities

Once the gate passes, the pipeline advances to Phase 7 (`/ship`).
