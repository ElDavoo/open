BEGIN;

ALTER TABLE "Account"
    DROP CONSTRAINT account_all_users_workspace_fk,
    DROP COLUMN all_users_workspace;

--- DB migration done
UPDATE "System"
   SET value = '107'
 WHERE field = 'socialtext-schema-version';

COMMIT;
