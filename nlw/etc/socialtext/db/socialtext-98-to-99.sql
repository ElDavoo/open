BEGIN;

DROP TABLE user_account_role CASCADE;
DROP TABLE group_account_role;
DROP TABLE group_workspace_role CASCADE;
DROP TABLE user_group_role;
DROP TABLE user_workspace_role CASCADE;

-- user_set_id indexes for groups/workspaces/accounts

CREATE UNIQUE INDEX groups_user_set_id ON groups (user_set_id);
CREATE UNIQUE INDEX workspace_user_set_id ON "Workspace" (user_set_id);
CREATE UNIQUE INDEX account_user_set_id ON "Account" (user_set_id);

-- indexes for user_set_include

CREATE UNIQUE INDEX idx_user_set_include_pkey_and_role
    ON user_set_include (from_set_id,into_set_id,role_id);
CREATE UNIQUE INDEX idx_user_set_include_rev_and_role
    ON user_set_include (into_set_id,from_set_id,role_id);


-- indexes for user_set_path

CREATE INDEX idx_user_set_path_wholepath_and_role
    ON user_set_path (from_set_id,into_set_id,role_id);
CREATE INDEX idx_user_set_path_rev_and_role
    ON user_set_path (into_set_id,from_set_id,role_id);
CREATE INDEX idx_user_set_path_via
    ON user_set_path (via_set_id,into_set_id);
-- Special index type to allow searching within an int[].  Requires the
-- "intarray" postgres extension for 8.1
CREATE INDEX idx_user_set_path_vlist
    ON user_set_path USING gist (vlist gist__int_ops);
-- TODO: partition indexes for users/non-users from_set_id

-- constraints

ALTER TABLE ONLY user_set_include
    ADD CONSTRAINT user_set_include_role
            FOREIGN KEY (role_id)
            REFERENCES "Role"(role_id) ON DELETE RESTRICT;
ALTER TABLE ONLY user_set_path
    ADD CONSTRAINT user_set_path_role
            FOREIGN KEY (role_id)
            REFERENCES "Role"(role_id) ON DELETE RESTRICT;

UPDATE "System"
   SET value = '99'
 WHERE field = 'socialtext-schema-version';

COMMIT;
