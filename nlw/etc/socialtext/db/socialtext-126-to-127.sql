BEGIN;

-- blah blah

CREATE TABLE topic_signal_link (
    signal_id integer NOT NULL,
    href text NOT NULL,
    title text
);

ALTER TABLE ONLY topic_signal_link
    ADD CONSTRAINT topic_signal_link_pk
            PRIMARY KEY (signal_id, href);

CREATE INDEX ix_topic_signal_link_forward
	    ON topic_signal_link (href);

CREATE INDEX ix_topic_signal_link_reverse
	    ON topic_signal_link (signal_id);

CREATE VIEW signal_asset AS
  SELECT signal_id, href, title,
         NULL AS workspace_id, NULL AS page_id,
         0 AS attachment_id,
         'weblink' AS class
   FROM topic_signal_link
UNION ALL 
  SELECT signal_id, NULL AS href, NULL AS title,
         workspace_id, page_id,
         0 AS attachment_id,
         'wikilink' AS class
   FROM topic_signal_page
UNION ALL 
  SELECT signal_id, NULL AS href, NULL AS title,
         NULL AS workspace_id, NULL AS page_id,
         attachment_id,
         'attachment' AS class
    FROM signal_attachment;
;

UPDATE "System"
   SET value = '127'
 WHERE field = 'socialtext-schema-version';
COMMIT;
