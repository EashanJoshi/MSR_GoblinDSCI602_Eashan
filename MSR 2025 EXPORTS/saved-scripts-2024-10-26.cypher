CALL db.labels()


// Count artifacts still using each version of org.jgrapht:jgrapht-core
MATCH (a:Artifact)-[e:relationship_AR]->(r:Release)
WHERE r.id STARTS WITH 'org.jgrapht:jgrapht-core'
RETURN r.version, count(a) AS LibraryUsage
ORDER BY r.version


// Count artifacts using org.jgrapht:jgrapht-core version 1.0.0
MATCH (a:Artifact)-[e:relationship_AR]->(r:Release)
WHERE r.id = 'org.jgrapht:jgrapht-core:1.0.0'
RETURN count(a) AS LU_1_0_0


// Count how many artifacts migrated from version 1.0.0 to any newer version
MATCH (a:Artifact)-[e1:relationship_AR]->(old:Release),
      (a)-[e2:relationship_AR]->(new:Release)
WHERE old.id = 'org.jgrapht:jgrapht-core:1.0.0'
  AND new.id STARTS WITH 'org.jgrapht:jgrapht-core'
  AND old.version < new.version
RETURN count(a) AS DependencyUpdatesFrom_1_0_0


// Find artifacts that migrated from version 1.0.0 to version 1.5.0
MATCH (a:Artifact)-[e1:relationship_AR]->(old:Release),
      (a)-[e2:relationship_AR]->(new:Release)
WHERE old.id = 'org.jgrapht:jgrapht-core:1.0.0'
  AND new.id = 'org.jgrapht:jgrapht-core:1.5.0'
RETURN count(a) AS DU_1_0_0_to_1_5_0


// Track migrations across all versions of org.jgrapht:jgrapht-core
MATCH (a:Artifact)-[e1:relationship_AR]->(old:Release),
      (a)-[e2:relationship_AR]->(new:Release)
WHERE old.id STARTS WITH 'org.jgrapht:jgrapht-core'
  AND new.id STARTS WITH 'org.jgrapht:jgrapht-core'
  AND old.version < new.version
RETURN old.version, new.version, count(a) AS MigrationCount
ORDER BY old.version, new.version