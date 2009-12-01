BEGIN;

DROP TABLE user_account_role CASCADE;
DROP TABLE group_account_role;
DROP TABLE group_workspace_role CASCADE;
DROP TABLE user_group_role;
DROP TABLE user_workspace_role CASCADE;

UPDATE "System"
   SET value = '99'
 WHERE field = 'socialtext-schema-version';

COMMIT;
