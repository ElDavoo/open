BEGIN;

-- Get rid of the container_type table, which is now handled in perl

ALTER TABLE container
    DROP CONSTRAINT container_type_fk;

DROP TABLE container_type;

-- Replace user_id, account_id, group_id, page_id, workspace_id with
-- user_set_id

ALTER TABLE container
    ADD COLUMN user_set_id integer;

UPDATE container
   SET user_set_id = group_id + x'10000000'::int
 WHERE group_id IS NOT NULL;

UPDATE container
   SET user_set_id = account_id + x'30000000'::int
 WHERE account_id IS NOT NULL;

UPDATE container
   SET user_set_id = user_id
 WHERE user_id IS NOT NULL;

ALTER TABLE container
    DROP CONSTRAINT container_scope_ptr,
    DROP COLUMN user_id,
    DROP COLUMN group_id,
    DROP COLUMN page_id,
    DROP COLUMN workspace_id,
    DROP COLUMN account_id,
    ALTER COLUMN user_set_id SET NOT NULL;

-- Done

UPDATE "System"
   SET value = '101'
 WHERE field = 'socialtext-schema-version';

COMMIT;
