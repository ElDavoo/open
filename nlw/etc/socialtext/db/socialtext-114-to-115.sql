BEGIN;

-- write your migration here
ALTER TABLE "groups"
    ADD COLUMN "permission_set" text NOT NULL DEFAULT 'private';

UPDATE "System"
   SET value = '115'
 WHERE field = 'socialtext-schema-version';
COMMIT;
