BEGIN;

ALTER TABLE "Account"
    DROP COLUMN all_users_workspace;

--- DB migration done
UPDATE "System"
   SET value = '107'
 WHERE field = 'socialtext-schema-version';

COMMIT;
