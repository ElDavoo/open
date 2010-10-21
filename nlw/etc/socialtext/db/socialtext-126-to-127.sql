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
    SELECT topic_signal_page.signal_id,
            '/' || "Workspace".name || '?' || topic_signal_page.page_id AS href,
            page.name AS title,
            topic_signal_page.workspace_id,
            topic_signal_page.page_id,
            0 AS attachment_id,
            'wikilink' AS "class"
       FROM topic_signal_page
       JOIN "Workspace" USING (workspace_id)
       JOIN page USING(workspace_id, page_id)
UNION ALL
    SELECT topic_signal_link.signal_id,
           topic_signal_link.href,
           topic_signal_link.title,
           NULL::"unknown" AS workspace_id,
           NULL::"unknown" AS page_id,
           0 AS attachment_id,
          'weblink' AS "class"
      FROM topic_signal_link
UNION ALL
    SELECT signal_attachment.signal_id,
           '/data/signals/' || hash || '/attachments/' || attachment_id AS href,
           filename AS title,
           NULL::"unknown" AS workspace_id,
           NULL::"unknown" AS page_id,
           signal_attachment.attachment_id, 'attachment' AS "class"
      FROM signal_attachment
      JOIN signal USING (signal_id)
      JOIN attachment USING (attachment_id);

CREATE VIEW conversation_tag AS
  SELECT tag.signal_id,
         tag.tag,
         signal.user_id
    FROM signal_tag tag
    JOIN signal USING(signal_id)
   WHERE NOT signal.hidden
UNION ALL
  SELECT signal.in_reply_to_id,
         tag.tag,
         signal.user_id
    FROM signal_tag tag
    JOIN signal USING(signal_id)
   WHERE signal.in_reply_to_id IS NOT NULL
     AND NOT signal.hidden;

CREATE INDEX tags_lower_tag 
           ON signal_tag (lower(tag) text_pattern_ops);

UPDATE "System"
   SET value = '127'
 WHERE field = 'socialtext-schema-version';
COMMIT;
