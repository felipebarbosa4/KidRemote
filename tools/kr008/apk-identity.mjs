// apksigner must already have exited successfully; accept one unambiguous certificate only.
export function certificateDigest(output) {
 const lines=output.split(/\r?\n/).filter(x=>x.includes('certificate SHA-256 digest:'));
 const values=lines.map(line=>line.match(/^(?:Signer #\d+|V[234](?:\.1)? Signer):? certificate SHA-256 digest: ([a-fA-F0-9]{64})$/)?.[1]?.toLowerCase());
 if(!values.length||values.some(x=>!x)||new Set(values).size!==1)throw Error('SIGNATURE_UNVERIFIED');
 return values[0];
}
