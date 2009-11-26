BEGIN;

ALTER TABLE groups
    ADD COLUMN description TEXT;

UPDATE "System"
   SET value = '97'
 WHERE field = 'socialtext-schema-version';

COMMIT;
