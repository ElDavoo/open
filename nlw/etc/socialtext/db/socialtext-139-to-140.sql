BEGIN;

ALTER TABLE gadget_content
    ALTER COLUMN view_name 
        DROP NOT NULL;

UPDATE "System"
   SET value = '140'
 WHERE field = 'socialtext-schema-version';

COMMIT;
