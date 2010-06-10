BEGIN;

-- For [Story: User adds tag to Signals]

CREATE TABLE signal_tag (
    signal_id bigint NOT NULL,
    tag text NOT NULL
);

ALTER TABLE ONLY signal_tag
    ADD CONSTRAINT signal_id_fk
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

CREATE INDEX idx_signal_tag_signal_id ON signal_tag(signal_id);
CREATE INDEX idx_signal_tag_tag ON signal_tag(tag);

-- For [Story: Update Signal Annotations to Match New Twitter Spec]
-- Nuke all old annotations in the old format.

UPDATE signal SET anno_blob = '[]';
UPDATE recent_signal SET anno_blob = '[]';

UPDATE "System"
   SET value = '120'
 WHERE field = 'socialtext-schema-version';

COMMIT;
