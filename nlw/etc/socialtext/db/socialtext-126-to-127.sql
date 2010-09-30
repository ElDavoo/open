BEGIN;

-- blah blah

CREATE TABLE topic_signal_link (
    signal_id integer NOT NULL,
    href text NOT NULL
);

ALTER TABLE ONLY topic_signal_link
    ADD CONSTRAINT topic_signal_link_pk
            PRIMARY KEY (signal_id, href);

CREATE INDEX ix_topic_signal_link_forward
	    ON topic_signal_link (href);

CREATE INDEX ix_topic_signal_link_reverse
	    ON topic_signal_link (signal_id);

UPDATE "System"
   SET value = '127'
 WHERE field = 'socialtext-schema-version';
COMMIT;
