# NT-MMS Client Provisioning Guide

## Overview

The NT-MMS backend provides a consolidated, idempotent command-line interface (CLI) to initialize a new client environment or migrate an existing database to the latest schema.

A single command:
1. Executes database migration scripts (`001_CreateAuthTables.sql` and `002_CreateRolePermissionTables.sql`).
2. Seeds and confirms the 18 Master Modules and 4 Actions (View, Add, Update, Delete).
3. Provisions or updates the initial System Administrator account with standard security defaults.

---

## Command Usage

From the project root:

```bash
dotnet run --project backend/MMSERP.Api.csproj -- --provision-client <username> <email> <password>
```

### Example

```bash
dotnet run --project backend/MMSERP.Api.csproj -- --provision-client admin admin@newtechmms.com AdminSecurePass123!
```

### Backward Compatibility

The legacy flag `--provision-admin` remains fully supported and behaves identically:

```bash
dotnet run --project backend/MMSERP.Api.csproj -- --provision-admin admin admin@newtechmms.com AdminSecurePass123!
```

---

## Environment Variable Mode

For containerized deployments (Docker / Kubernetes / Cloud Run) where interactive CLI arguments are not used, provisioning can be triggered automatically on application startup via environment variables:

- `INITIAL_ADMIN_PASSWORD` (Required to trigger provisioning)
- `INITIAL_ADMIN_USERNAME` (Optional, defaults to `admin`)
- `INITIAL_ADMIN_EMAIL` (Optional, defaults to `admin@newtechmms.com`)

If `INITIAL_ADMIN_PASSWORD` is set and the database already contains an active admin account that is not pending provisioning, the service logs an informational notice and safely skips re-provisioning.

---

## Security Invariants & Guarantees

1. **Password Policy**:
   - Passwords must be at least 10 characters in length.
   - Purely numeric passwords are strictly rejected.
   - Hashed using BCrypt with a work factor of 11.

2. **Admin Role Isolation**:
   - Initial administrator accounts are provisioned with:
     - `IsAdmin = true`
     - `RoleId = NULL`
     - `MustChangePassword = true`
     - `IsActive = true`
   - In accordance with the system authorization model, administrators bypass the role-permission matrix.

3. **Idempotency**:
   - Migration scripts utilize SQL Server `IF NOT EXISTS` checks and `MERGE` statements.
   - Running `--provision-client` multiple times is completely safe and produces no duplicate rows or errors.
   - If the user already exists, their password is updated, account status is ensured active, failed login counters are cleared, and an audit trail entry is written to `AuthAuditLog`.

4. **Database Verification**:
   - Upon completion of migration scripts, the CLI queries and confirms:
     - 18 Modules seeded in `Modules` table.
     - 4 Actions (`View`, `Add`, `Update`, `Delete`) seeded in `Actions` table.

---

## Verification Output

Successful execution outputs:

```text
✔ Migration script '001_CreateAuthTables.sql' executed successfully.
✔ Migration script '002_CreateRolePermissionTables.sql' executed successfully.
✔ Database seed confirmed: 18 Modules, 4 Actions active in system.
✔ Admin user 'admin' successfully provisioned with MustChangePassword = true, IsAdmin = true, RoleId = NULL.
```
