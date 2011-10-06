BEGIN;

ALTER TABLE ONLY theme
    ADD COLUMN icon_set TEXT NOT NULL DEFAULT '';

UPDATE "System"
   SET value = '151'
 WHERE field = 'socialtext-schema-version';

COMMIT;
