BEGIN;

CREATE OR REPLACE FUNCTION is_ignorable_action(event_class text, "action" text) RETURNS boolean
    AS $$
BEGIN
    IF event_class = 'page' THEN
        RETURN action IN ('view', 'edit_start', 'edit_cancel', 'edit_contention');

    ELSIF event_class = 'person' THEN
        RETURN action = 'view';

    ELSIF event_class = 'signal' THEN
        RETURN false;

    ELSIF event_class = 'widget' THEN
        RETURN action != 'add';

    END IF;

    -- ignore all other event classes:
    RETURN true;
END;
$$
    LANGUAGE plpgsql IMMUTABLE;

--- DB migration done
UPDATE "System"
   SET value = '106'
 WHERE field = 'socialtext-schema-version';

COMMIT;
