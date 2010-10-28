BEGIN;

CREATE TABLE topic_signal_link (
    signal_id integer NOT NULL,
    href text NOT NULL,
    title text
);

ALTER TABLE ONLY topic_signal_link
    ADD CONSTRAINT topic_signal_link_pk
            PRIMARY KEY (signal_id, href);

ALTER TABLE ONLY topic_signal_link
    ADD CONSTRAINT topic_signal_link_signal_fk
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

CREATE UNIQUE INDEX ix_topic_signal_link_reverse
	    ON topic_signal_link (href, signal_id);

create table signal_asset (
    signal_id     bigint  NOT NULL,
-- TODO at
-- TODO recipient_id
    href          text    NOT NULL,
    title         text    ,
    workspace_id  integer ,
    page_id       text    , -- TODO: is this column needed?
    attachment_id integer , -- TODO: is this column needed?
    class         text    NOT NULL
);

INSERT INTO signal_asset
    SELECT topic_signal_page.signal_id,
            '/' || "Workspace".name || '?' || topic_signal_page.page_id AS href,
            page.name AS title,
            topic_signal_page.workspace_id,
            topic_signal_page.page_id,
            NULL AS attachment_id,
            'wikilink' AS "class"
       FROM topic_signal_page
       JOIN "Workspace" USING (workspace_id)
       JOIN page USING(workspace_id, page_id);

INSERT INTO signal_asset
    SELECT topic_signal_link.signal_id,
           topic_signal_link.href,
           topic_signal_link.title,
           NULL AS workspace_id,
           NULL AS page_id,
           NULL AS attachment_id,
          'weblink' AS "class"
      FROM topic_signal_link;

INSERT INTO signal_asset
    SELECT signal_attachment.signal_id,
           '/data/signals/' || hash || '/attachments/' || attachment_id AS href,
           filename AS title,
           NULL AS workspace_id,
           NULL AS page_id,
           signal_attachment.attachment_id,
           'attachment' AS "class"
      FROM signal_attachment
      JOIN signal USING (signal_id)
      JOIN attachment USING (attachment_id);

-- TODO: which of these are actually needed?
CREATE INDEX ix_sigasset_sigid ON signal_asset (signal_id);
CREATE INDEX ix_sigasset_pageid ON signal_asset (workspace_id, page_id);
CREATE INDEX ix_sigasset_attid ON signal_asset (attachment_id);
CREATE INDEX ix_sigasset_class ON signal_asset (class);
CREATE INDEX ix_sigasset_href ON signal_asset (href);
CREATE INDEX ix_sigasset_classsigid ON signal_asset (class, signal_id);
CREATE INDEX ix_sigasset_sigidclass ON signal_asset (signal_id, class);
CREATE INDEX ix_sigasset_chs ON signal_asset (class, href, signal_id);
CREATE INDEX ix_sigasset_ch ON signal_asset (class, href);

ALTER TABLE ONLY signal_asset
    ADD CONSTRAINT signal_asset_signal_fk
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal_asset
    ADD CONSTRAINT signal_asset_ws_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal_asset
    ADD CONSTRAINT signal_asset_attach_fk
            FOREIGN KEY (attachment_id)
            REFERENCES attachment(attachment_id) ON DELETE CASCADE;


CREATE TABLE signal_thread_tag (
    signal_id bigint NOT NULL,
    tag text NOT NULL,
    user_id bigint NOT NULL
);

INSERT INTO signal_thread_tag
 SELECT tag.signal_id, lower(tag.tag), signal.user_id
   FROM signal_tag tag
   JOIN signal USING (signal_id)
  WHERE NOT signal.hidden
UNION
 SELECT signal.in_reply_to_id AS signal_id, lower(tag.tag), signal.user_id
   FROM signal_tag tag
   JOIN signal USING (signal_id)
  WHERE signal.in_reply_to_id IS NOT NULL AND NOT signal.hidden;

CREATE UNIQUE INDEX ix_sigthrtag_unique
    ON signal_thread_tag (tag, user_id, signal_id);
CREATE INDEX ix_sigthrtag_tagsig
    ON signal_thread_tag (tag, signal_id);
CREATE INDEX ix_sigthrtag_usersig
    ON signal_thread_tag (user_id, signal_id);
CREATE INDEX ix_sigthrtag_sigid
    ON signal_thread_tag (signal_id);

-- speed up tag lookahead (all users)
CREATE INDEX ix_sigthrtag_tagtpo
    ON signal_thread_tag (tag text_pattern_ops);
-- speed up tag lookahead (specific users)
CREATE INDEX ix_sigthrtag_tagusersigtpo
    ON signal_thread_tag (tag text_pattern_ops, user_id);

ALTER TABLE ONLY signal_thread_tag
    ADD CONSTRAINT signal_thread_tag_signal_fk
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal_thread_tag
    ADD CONSTRAINT signal_thread_tag_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE RESTRICT;

-- why is this needed? ~stash
CREATE INDEX idx_signal_tag_lower_tag 
           ON signal_tag (lower(tag) text_pattern_ops);

UPDATE "System"
   SET value = '127'
 WHERE field = 'socialtext-schema-version';
COMMIT;
