import { readFileSync, mkdtempSync, writeFileSync, unlinkSync, rmdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, dirname, posix } from "node:path";
import { execFileSync } from "node:child_process";

const root = resolve(dirname(new URL(import.meta.url).pathname), "..");
const config = JSON.parse(readFileSync(resolve(root,"docs/github/project.json"),"utf8"));
const issues = JSON.parse(readFileSync(resolve(root,"docs/github/issues.json"),"utf8"));
const args = process.argv.slice(2);
if (args.some(a => a !== "--apply")) throw new Error("Usage: node tools/publish-planning.mjs [--apply]");
const apply = args.includes("--apply");
const gh = (...a) => execFileSync("gh",a,{cwd:root,encoding:"utf8",stdio:["ignore","pipe","pipe"]}).trim();
const json = (...a) => JSON.parse(gh(...a));
if (!apply) {
  process.stdout.write(JSON.stringify({mode:"DRY RUN — no writes",repository:config.repository,labels:config.labels.map(l=>l.name),milestones:config.milestones.map(m=>m.title),issues:issues.map(i=>({id:i.id,title:i.title,body_file:i.body_file})),apply:"node tools/publish-planning.mjs --apply"},null,2)+"\n");
  process.exit(0);
}
const remote = execFileSync("git",["remote","get-url","origin"],{cwd:root,encoding:"utf8"}).trim();
if (![ "https://github.com/"+config.repository+".git", "git@github.com:"+config.repository+".git"].includes(remote)) throw new Error("Origin does not match configured planning target");
const repo = json("repo","view",config.repository,"--json","nameWithOwner,hasIssuesEnabled,viewerPermission");
if (!repo.hasIssuesEnabled || !["ADMIN","MAINTAIN","WRITE"].includes(repo.viewerPermission)) throw new Error("Issue write permission unavailable");
const labels = new Set(json("label","list","--repo",config.repository,"--limit","100","--json","name").map(x=>x.name));
for (const l of config.labels) {
  if (!labels.has(l.name)) gh("label","create",l.name,"--repo",config.repository,"--color",l.color,"--description",l.description);
}
let milestones = json("api","repos/"+config.repository+"/milestones?state=all&per_page=100");
for (const m of config.milestones) {
  if (!milestones.some(x=>x.title===m.title)) {
    milestones.push(json("api","--method","POST","repos/"+config.repository+"/milestones","-f","title="+m.title,"-f","description="+m.description));
  }
}
const existing = json("issue","list","--repo",config.repository,"--state","all","--limit","1000","--json","number,title,url");
const published = [];
for (const issue of issues) {
  const matches = existing.filter(e=>e.title.startsWith(issue.id+":"));
  if (matches.length > 1) throw new Error("Ambiguous existing "+issue.id);
  if (matches.length) {
    published.push({id:issue.id,...matches[0],created:false});
    continue; // Preserve existing human issue edits.
  }
  const body = readFileSync(resolve(root,issue.body_file),"utf8").replace(/\]\(([^)\n]+)\)/g,(whole,target)=>{
    if (/^(https?:|#)/.test(target)) return whole;
    const path = posix.normalize(posix.join(posix.dirname(issue.body_file),target));
    if (path.startsWith("../")) throw new Error("Issue link escapes repo");
    return "](https://github.com/"+config.repository+"/blob/"+config.source_ref+"/"+path+")";
  });
  // A unique temporary body file preserves actual newlines without shell interpolation.
  const tempDir = mkdtempSync(resolve(tmpdir(), "kidremote-issue-"));
  const bodyPath = resolve(tempDir, issue.id + ".md");
  writeFileSync(bodyPath, body, {mode:0o600});
  const flags = ["issue","create","--repo",config.repository,"--title",issue.title,"--body-file",bodyPath,"--milestone",issue.milestone];
  for (const label of issue.labels) flags.push("--label",label);
  let url;
  try { url = execFileSync("gh",flags,{cwd:root,encoding:"utf8",stdio:["ignore","pipe","pipe"]}).trim(); }
  finally { unlinkSync(bodyPath); rmdirSync(tempDir); }
  const number = Number(url.split("/").at(-1));
  if (!Number.isInteger(number)) throw new Error("Unexpected create response: "+url);
  published.push({id:issue.id,number,title:issue.title,url,created:true});
}
process.stdout.write(JSON.stringify({repository:config.repository,milestones:milestones.filter(m=>config.milestones.some(x=>x.title===m.title)).map(m=>({number:m.number,title:m.title,url:m.html_url})),issues:published,project:"Not changed by this publisher; reconcile the existing Project with tools/setup-project.mjs and PROJECT.md."},null,2)+"\n");
