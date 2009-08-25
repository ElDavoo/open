BEGIN;

DROP INDEX ix_event_at_signal_id_not_null;

CREATE INDEX ix_event_signal_ref ON event ("at")
    WHERE signal_id IS NOT NULL;

CREATE INDEX ix_event_signal_ref_actions ON event ("at")
    WHERE action IN ('signal','edit_save') AND signal_id IS NOT NULL;

CREATE FUNCTION is_ignorable_action("event_class" text, "action" text) RETURNS boolean
    AS $$
BEGIN
    IF event_class = 'page' THEN
        RETURN action IN ('view', 'edit_start', 'edit_cancel', 'edit_contention', 'watch_add', 'watch_delete');

    ELSIF event_class = 'person' THEN
        RETURN action IN ('view', 'watch_add', 'watch_delete');

    ELSIF event_class = 'signal' THEN
        RETURN false;

    ELSIF event_class = 'widget' THEN
        RETURN action NOT IN ('add');

    END IF;

    -- ignore all other event classes:
    RETURN true;
END;
$$
    LANGUAGE plpgsql IMMUTABLE;

CREATE INDEX ix_event_activity_ignore ON event ("at")
    WHERE NOT is_ignorable_action(event_class, action);

UPDATE "System"
   SET value = '82'
 WHERE field = 'socialtext-schema-version';

COMMIT;
