BEGIN;

CREATE TABLE user_set_role_permission (
    user_set_id     integer NOT NULL,
    role_id         integer NOT NULL,
    permission_id   integer NOT NULL
);


ALTER TABLE ONLY user_set_role_permission
    ADD CONSTRAINT usrp_pk
        PRIMARY KEY (user_set_id, role_id, permission_id);
ALTER TABLE ONLY user_set_role_permission
    ADD CONSTRAINT usrp_role_fk
        FOREIGN KEY (role_id)
        REFERENCES "Role"(role_id) ON DELETE RESTRICT;
ALTER TABLE ONLY user_set_role_permission
    ADD CONSTRAINT usrp_permission_fk
        FOREIGN KEY (permission_id)
        REFERENCES "Permission"(permission_id) ON DELETE RESTRICT;

-- we'll likely want to do sub-queries like:
-- IN (SELECT user_set_id FROM user_set_role_permission WHERE permission_id = ?
CREATE INDEX usrp_perm_lookup_ix
    ON user_set_role_permission (permission_id, user_set_id);
CREATE INDEX usrp_perm_lookup_rev_ix
    ON user_set_role_permission (user_set_id, permission_id);

UPDATE "System"
   SET value = '115'
 WHERE field = 'socialtext-schema-version';
COMMIT;
