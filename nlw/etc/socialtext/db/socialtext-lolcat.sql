-- Migrations for lolcat

-- TODO: truncate from_page_id, to_page_id to 255

ALTER TABLE ONLY page_link
    ADD CONSTRAINT page_link_unique
            UNIQUE (from_workspace_id, from_page_id, to_workspace_id, to_page_id);

CREATE INDEX page_link__to_page
	    ON page_link (to_workspace_id, to_page_id);


-- ensure that all User's have a default value for their "middle_name"
UPDATE users SET middle_name='';

-- Create new "user_restrictions" table, to replace the "UserEmailConfirmation"
-- table.  Then, migrate the existing data and remove the old table.
CREATE TABLE user_restrictions (
    user_id             BIGINT       NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    restriction_type    VARCHAR(256) NOT NULL,
    token               VARCHAR(128) NOT NULL,
    expires_at          TIMESTAMPTZ  NOT NULL DEFAULT '-infinity'::TIMESTAMPTZ,
    workspace_id        BIGINT REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, restriction_type)
);
CREATE INDEX user_restrictions_user_id_key ON user_restrictions(user_id);
CREATE INDEX user_restrictions_token_key ON user_restrictions(token);

INSERT INTO user_restrictions (
    user_id, restriction_type, token, expires_at, workspace_id
    )
    SELECT user_id, 'email-confirmation', sha1_hash, expiration_datetime, workspace_id
      FROM "UserEmailConfirmation"
     WHERE is_password_change = false;

INSERT INTO user_restrictions (
    user_id, restriction_type, token, expires_at
    )
    SELECT user_id, 'password-change', sha1_hash, expiration_datetime
      FROM "UserEmailConfirmation"
     WHERE is_password_change = true;

DROP TABLE "UserEmailConfirmation";

-- Populate the page "tags" column from the current page_rev
UPDATE page
   SET tags = latest.tags
  FROM (
        SELECT page_id, workspace_id, tags
          FROM page_revision
          JOIN (
            SELECT page_id, workspace_id, MAX(revision_id) AS revision_id
              FROM page_revision
             GROUP BY page_id, workspace_id
          ) max_rev USING (page_id, workspace_id, revision_id)
    ) latest
 WHERE page.page_id = latest.page_id AND page.workspace_id = latest.workspace_id;
