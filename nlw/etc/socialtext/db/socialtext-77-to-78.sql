BEGIN;

ALTER TABLE signal
    ADD COLUMN hidden BOOLEAN DEFAULT FALSE;

ALTER TABLE event
    ADD COLUMN hidden BOOLEAN DEFAULT FALSE;

UPDATE "System"
   SET value = '78'
 WHERE field = 'socialtext-schema-version';

COMMIT;
