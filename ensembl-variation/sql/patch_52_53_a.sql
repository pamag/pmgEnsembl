# update the schema_version entry in the meta table
##################
update meta set meta_value = 53 where meta_key = 'schema_version';

# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL,'patch', 'patch_52_53_a.sql|schema version');
