-- Migrations for lolcat

-- TODO: truncate from_page_id, to_page_id to 255

ALTER TABLE ONLY page_link
    ADD CONSTRAINT page_link_unique
            UNIQUE (from_workspace_id, from_page_id, to_workspace_id, to_page_id);

CREATE INDEX page_link__to_page
	    ON page_link (to_workspace_id, to_page_id);

-- ensure that all User's have a default value for their "middle_name"
UPDATE users SET middle_name='';
