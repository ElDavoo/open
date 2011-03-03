BEGIN;

-- Migrations for lolcat

-- Add missing NOT NULL and DEFAULT to "Account" table.
UPDATE "Account"
   SET email_addresses_are_hidden = false
 WHERE email_addresses_are_hidden IS NULL;

ALTER TABLE "Account"
    ALTER email_addresses_are_hidden SET NOT NULL,
    ALTER email_addresses_are_hidden SET DEFAULT false;

-- TODO: truncate from_page_id, to_page_id to 255

ALTER TABLE ONLY page_link
    ADD CONSTRAINT page_link_unique
            UNIQUE (from_workspace_id, from_page_id, to_workspace_id, to_page_id);

CREATE INDEX page_link__to_page
	    ON page_link (to_workspace_id, to_page_id);

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

UPDATE "System"
   SET value = '134'
 WHERE field = 'socialtext-schema-version';

COMMIT;
