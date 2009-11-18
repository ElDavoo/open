BEGIN;

ALTER TABLE event
    ADD COLUMN group_id bigint;

CREATE INDEX ix_event_for_group
    ON event (group_id, "at")
    WHERE (event_class = 'group');

UPDATE "System"
   SET value = '93'
 WHERE field = 'socialtext-schema-version';

COMMIT;
