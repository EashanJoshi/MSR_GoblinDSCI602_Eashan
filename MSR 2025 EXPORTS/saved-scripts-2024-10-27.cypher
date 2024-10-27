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


// The query identifies the top 10 most popular libraries based on their 1-year popularity, retrieves their releases, and fetches the associated added values (e.g., popularity, freshness, vulnerabilities), providing a comprehensive overview of these libraries.

// Step 1: Fetch top 10 library IDs from Artifact nodes, not Release nodes
MATCH (a:Artifact)-[:relationship_AR]->(r:Release)-[:addedValues]->(v:AddedValue)
WHERE v.type = 'POPULARITY_1_YEAR' AND toInteger(v.value) > 0
WITH a.id AS LibraryID
ORDER BY toInteger(v.value) DESC
LIMIT 10
WITH collect(LibraryID) AS topLibraries

// Step 2: Match Artifact nodes using collected IDs
MATCH (a:Artifact)
WHERE a.id IN topLibraries
OPTIONAL MATCH (a)-[:relationship_AR]->(release:Release)
OPTIONAL MATCH (release)-[:addedValues]->(addedValue:AddedValue)
RETURN a.id AS LibraryID, 
       release.id AS ReleaseID, 
       release.version AS Version, 
       addedValue.type AS AddedValueType,
       addedValue.value AS AddedValue
ORDER BY LibraryID, ReleaseID, AddedValueType;


// This query compares dependencies between the all the versions 
// for each of the top libraries, identifying added and removed dependencies.

// Step 1: Fetch the top 10 libraries based on POPULARITY_1_YEAR
MATCH (a:Artifact)-[:relationship_AR]->(r:Release)-[:addedValues]->(v:AddedValue)
WHERE v.type = 'POPULARITY_1_YEAR' AND toInteger(v.value) > 0
WITH a.id AS LibraryID
ORDER BY toInteger(v.value) DESC
LIMIT 10

// Step 2: Collect all versions of each library
MATCH (a:Artifact)-[:relationship_AR]->(release:Release)
WHERE a.id = LibraryID
WITH a.id AS LibraryID, release.version AS Version
ORDER BY LibraryID, toInteger(replace(Version, '.', '')) ASC
WITH LibraryID, collect(Version) AS versions

// Step 3: Loop through each library and its versions
UNWIND range(0, size(versions) - 2) AS idx
WITH LibraryID, versions[idx] AS PreviousVersion, versions[idx + 1] AS NewestVersion

// Match the dependencies of the newest version
MATCH (a:Artifact {id: LibraryID})-[:relationship_AR]->(newRelease:Release {version: NewestVersion})
OPTIONAL MATCH (newRelease)-[:dependency]->(newDep:Artifact)

// Match the dependencies of the previous version
MATCH (a)-[:relationship_AR]->(oldRelease:Release {version: PreviousVersion})
OPTIONAL MATCH (oldRelease)-[:dependency]->(oldDep:Artifact)

// Identify added and removed dependencies between consecutive versions
WITH LibraryID, NewestVersion, PreviousVersion, 
     collect(DISTINCT newDep.id) AS NewDeps, 
     collect(DISTINCT oldDep.id) AS OldDeps

WITH LibraryID, NewestVersion, PreviousVersion, 
     [dep IN NewDeps WHERE NOT dep IN OldDeps] AS AddedDeps, 
     [dep IN OldDeps WHERE NOT dep IN NewDeps] AS RemovedDeps

// Return results
RETURN LibraryID, PreviousVersion, NewestVersion, AddedDeps, RemovedDeps
ORDER BY LibraryID, NewestVersion;


// This query compares dependencies between the two latest versions 
// for each of the top libraries, identifying added and removed dependencies.

// Step 1: Fetch the top 10 libraries based on POPULARITY_1_YEAR
MATCH (a:Artifact)-[:relationship_AR]->(r:Release)-[:addedValues]->(v:AddedValue)
WHERE v.type = 'POPULARITY_1_YEAR' AND toInteger(v.value) > 0
WITH a.id AS LibraryID
ORDER BY toInteger(v.value) DESC
LIMIT 10

// Step 2: For each library, get the latest two versions
MATCH (a:Artifact)-[:relationship_AR]->(release:Release)
WHERE a.id = LibraryID
WITH a.id AS LibraryID, release.version AS Version
ORDER BY toInteger(replace(Version, '.', '')) DESC
WITH LibraryID, collect(Version)[0..2] AS versions
WHERE size(versions) = 2

// Step 3: Construct the dynamic list
WITH collect([LibraryID, versions[0], versions[1]]) AS libraries

// Step 4: Use the dynamically constructed list in the next steps
UNWIND libraries AS lib

// Extract library ID, newest version, and previous version
WITH lib[0] AS LibraryID, lib[1] AS NewestVersion, lib[2] AS PreviousVersion

// Match the dependencies of the newest version
MATCH (a:Artifact {id: LibraryID})-[:relationship_AR]->(newRelease:Release {version: NewestVersion})
OPTIONAL MATCH (newRelease)-[:dependency]->(newDep:Artifact)

// Match the dependencies of the previous version
MATCH (a)-[:relationship_AR]->(oldRelease:Release {version: PreviousVersion})
OPTIONAL MATCH (oldRelease)-[:dependency]->(oldDep:Artifact)

// Identify added and removed dependencies
WITH LibraryID, 
     collect(DISTINCT newDep.id) AS NewDeps, 
     collect(DISTINCT oldDep.id) AS OldDeps
WITH LibraryID, 
     [dep IN NewDeps WHERE NOT dep IN OldDeps] AS AddedDeps, 
     [dep IN OldDeps WHERE NOT dep IN NewDeps] AS RemovedDeps

// Return results
RETURN LibraryID, AddedDeps, RemovedDeps
ORDER BY LibraryID;


// Track migrations across all versions of org.jgrapht:jgrapht-core
MATCH (a:Artifact)-[e1:relationship_AR]->(old:Release),
      (a)-[e2:relationship_AR]->(new:Release)
WHERE old.id STARTS WITH 'org.jgrapht:jgrapht-core'
  AND new.id STARTS WITH 'org.jgrapht:jgrapht-core'
  AND old.version < new.version
RETURN old.version, new.version, count(a) AS MigrationCount
ORDER BY old.version, new.version