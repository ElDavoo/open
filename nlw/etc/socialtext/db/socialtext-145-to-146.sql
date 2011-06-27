BEGIN;

-- Add a counter for 
ALTER TABLE signal ADD COLUMN like_count bigint DEFAULT 0;
ALTER TABLE recent_signal ADD COLUMN like_count bigint DEFAULT 0;

-- Index for ordering list views by likes
CREATE INDEX recent_signal_likes_count_idx
    ON recent_signal(like_count);

CREATE OR REPLACE FUNCTION update_like_count() RETURNS trigger AS $update_like_count$
    BEGIN
        IF (TG_OP = 'INSERT') THEN
            IF NEW.page_id IS NOT NULL AND NEW.revision_id IS NULL THEN
                UPDATE page
                   SET like_count = like_count + 1
                 WHERE page.workspace_id = NEW.workspace_id
                   AND page.page_id = NEW.page_id;
            ELSIF NEW.signal_id IS NOT NULL THEN
                UPDATE signal
                   SET like_count = like_count + 1
                 WHERE signal.signal_id = NEW.signal_id;
                UPDATE recent_signal
                   SET like_count = like_count + 1
                 WHERE signal_id = NEW.signal_id;
            END IF;
            RETURN NEW;
        ELSIF (TG_OP = 'DELETE') THEN
            IF OLD.page_id IS NOT NULL AND OLD.revision_id IS NULL THEN
                UPDATE page
                   SET like_count = like_count - 1
                 WHERE page.workspace_id = OLD.workspace_id
                   AND page.page_id = OLD.page_id;
            ELSIF OLD.signal_id IS NOT NULL THEN
                UPDATE signal
                   SET like_count = like_count - 1
                 WHERE signal.signal_id = OLD.signal_id;
                UPDATE recent_signal
                   SET like_count = like_count - 1
                 WHERE signal_id = OLD.signal_id;
            END IF;
            RETURN OLD;
        END IF;
        RETURN NULL;
    END;
$update_like_count$ LANGUAGE plpgsql;

UPDATE "System"
   SET value = '146'
 WHERE field = 'socialtext-schema-version';

COMMIT;
