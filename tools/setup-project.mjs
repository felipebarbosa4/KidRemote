import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { execFileSync } from "node:child_process";
const root=resolve(dirname(new URL(import.meta.url).pathname),"..");
const c=JSON.parse(readFileSync(resolve(root,"docs/github/project.json"),"utf8"));
const issues=JSON.parse(readFileSync(resolve(root,"docs/github/issues.json"),"utf8"));
const args=process.argv.slice(2);
if(args.some(a=>a!=="--apply")) throw new Error("Usage: node tools/setup-project.mjs [--apply]");
if(!args.includes("--apply")){
  process.stdout.write(JSON.stringify({mode:"DRY RUN — no writes",configuration:c,project_policy:"Reuse one existing exact-title Project; never create implicitly",manual:"UI-only filters, sorts, grouping, roadmap mapping and workflow actions: follow docs/github/PROJECT.md"},null,2)+"\n");
  process.exit(0);
}
const gh=(...a)=>execFileSync("gh",a,{cwd:root,encoding:"utf8",stdio:["ignore","pipe","pipe"]}).trim();
const j=(...a)=>JSON.parse(gh(...a));
let available;
try{ available=j("project","list","--owner",c.owner,"--limit","100","--format","json").projects; }
catch(e){
  process.stderr.write("Project access unavailable. No Project writes attempted.\n"+(e.stderr?.toString()??e.message)+"\nSee docs/github/PROJECT.md for the human scope authorization command.\n");
  process.exit(2);
}
const matches=available.filter(p=>p.title===c.title);
if(matches.length>1) throw new Error("Multiple matching projects; resolve target explicitly");
if(!matches.length) throw new Error("No exact existing Project named "+c.title+"; no Project created. Reconcile the intended target in docs/github/PROJECT.md.");
const p=matches[0];
gh("project","link",String(p.number),"--owner",c.owner,"--repo",c.repository);
let fields=j("project","field-list",String(p.number),"--owner",c.owner,"--limit","100","--format","json").fields;
for(const f of c.fields){
  if(f.builtin||f.type==="ITERATION"||fields.some(x=>x.name===f.name)) continue;
  const flags=["project","field-create",String(p.number),"--owner",c.owner,"--name",f.name,"--data-type",f.type,"--format","json"];
  if(f.options) flags.push("--single-select-options",f.options.join(","));
  j(...flags);
}
fields=j("project","field-list",String(p.number),"--owner",c.owner,"--limit","100","--format","json").fields;
const repoIssues=j("issue","list","--repo",c.repository,"--state","all","--limit","1000","--json","number,title,url");
const projectItems=j("project","item-list",String(p.number),"--owner",c.owner,"--limit","1000","--format","json").items;
const outputKey=name=>name[0].toLowerCase()+name.slice(1);
const notes=[];
for(const i of issues){
  const candidates=repoIssues.filter(x=>x.title.startsWith(i.id+":"));
  if(candidates.length!==1){notes.push(i.id+": missing/ambiguous issue; run issue publisher first");continue;}
  const item=j("project","item-add",String(p.number),"--owner",c.owner,"--url",candidates[0].url,"--format","json");
  const current=projectItems.find(x=>x.id===item.id)??item;
  const values={"Status":i.status,"Priority":i.priority,"Story Points":i.story_points,"Risk":i.risk,"Area":i.area,"Platform":i.platform,"Decision Required":i.decision_required,"Work Type":i.work_type};
  for(const [name,value] of Object.entries(values)){
    const field=fields.find(f=>f.name===name);
    if(!field){notes.push("Missing field "+name);continue;}
    const existing=current[outputKey(name)];
    if(existing!==undefined&&existing!==null&&existing!==""){
      if(existing!==value) notes.push("Preserved live "+i.id+" "+name+"="+existing+" (initial manifest "+value+")");
      continue;
    }
    const base=["project","item-edit","--id",item.id,"--project-id",p.id,"--field-id",field.id];
    if(typeof value==="number") gh(...base,"--number",String(value));
    else {
      const option=field.options?.find(o=>o.name===value);
      if(!option){notes.push("Configure "+name+" option "+value+" in UI then rerun");continue;}
      gh(...base,"--single-select-option-id",option.id);
    }
  }
}
process.stdout.write(JSON.stringify({project:p,notes:[...new Set(notes)],manual_remaining:"Complete/verify UI-only filters, sorts, grouping, roadmap date mapping and workflow actions; see docs/github/PROJECT.md."},null,2)+"\n");
