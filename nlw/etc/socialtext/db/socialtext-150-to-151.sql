BEGIN;

ALTER TABLE ONLY theme
    ADD COLUMN icon_set TEXT NOT NULL DEFAULT '';

ALTER TABLE ONLY theme
    ADD COLUMN logo_image_id bigint NOT NULL;

ALTER TABLE ONLY theme
    ADD CONSTRAINT theme_logo_image_fk
             FOREIGN KEY (logo_image_id)
             REFERENCES attachment(attachment_id) ON DELETE RESTRICT;

UPDATE "System"
   SET value = '151'
 WHERE field = 'socialtext-schema-version';

COMMIT;
