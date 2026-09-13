// Release resource optimization may shorten file paths. Resolve the named resource,
// never assume its ZIP path or skip the packaged XML check.
export function backupResourcePath(table,name) {
 if(!['backup_rules','extraction_rules'].includes(name))throw Error('BACKUP_RESOURCE_NAME');
 const matches=[...table.matchAll(new RegExp('resource 0x[0-9a-f]+ xml/'+name+'\\r?\\n\\s+\\(\\) \\(file\\) ([^\\s]+) type=XML','g'))];
 if(matches.length!==1||!/^res\/[A-Za-z0-9_./-]+\.xml$/.test(matches[0][1])||matches[0][1].includes('..'))throw Error('PACKAGED_BACKUP_RESOURCE_UNRESOLVED');
 return matches[0][1];
}
