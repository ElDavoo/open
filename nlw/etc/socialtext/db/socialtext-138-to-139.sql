BEGIN;

-- This shouldn't do anything in actual migrations from lolcat, but is
-- required if we are upgrading from older megasharks
DELETE FROM gadget
    WHERE src = 'local:widgets:activities.xml'
       OR src = 'local:people:all_tags.xml';

-- Point all activities widgets to the new location
UPDATE gadget
   SET src = 'local:widgets:activities.xml'
 WHERE src = 'local:widgets:activities';

UPDATE gadget
   SET src = 'local:people:all_tags.xml'
 WHERE src = 'local:people:all_tags';

UPDATE "System"
   SET value = '139'
 WHERE field = 'socialtext-schema-version';

COMMIT;
