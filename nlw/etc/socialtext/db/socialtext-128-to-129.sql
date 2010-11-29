BEGIN;

-- Add an xml column for storing actual XML data for widgets

ALTER TABLE gadget
    ADD COLUMN xml text;

UPDATE "System"
   SET value = '129'
 WHERE field = 'socialtext-schema-version';
COMMIT;
