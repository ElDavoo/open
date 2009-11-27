BEGIN;

ALTER TABLE groups
    ADD COLUMN description TEXT;

ALTER TABLE container_type
    ADD COLUMN footer_template TEXT;

UPDATE "System"
   SET value = '97'
 WHERE field = 'socialtext-schema-version';

COMMIT;
