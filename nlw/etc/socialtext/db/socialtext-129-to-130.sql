BEGIN;

ALTER TABLE users
    ADD COLUMN private_external_id TEXT;

UPDATE "System"
   SET value = '130'
 WHERE field = 'socialtext-schema-version';

COMMIT;
