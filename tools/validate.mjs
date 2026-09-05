import { readFileSync, readdirSync, existsSync } from "node:fs";
import { resolve, dirname, relative } from "node:path";

const root = resolve(import.meta.dirname ?? dirname(new URL(import.meta.url).pathname), "..");
const errors = [];
const read = p => readFileSync(resolve(root, p), "utf8");
const check = (ok, message) => { if (!ok) errors.push(message); };
function walk(dir) {
  return readdirSync(resolve(root, dir), { withFileTypes: true }).flatMap(e => {
    if ([".git", "node_modules", ".gradle"].includes(e.name)) return [];
    const p = dir ? dir + "/" + e.name : e.name;
    return e.isDirectory() ? walk(p) : [p];
  });
}
const files = walk("");
for (const path of files.filter(p => p.endsWith(".md"))) {
  const body = read(path);
  for (const match of body.matchAll(/\[[^\]\n]*\]\(([^)\n]+)\)/g)) {
    let target = match[1].replace(/^<|>$/g, "").split("#")[0];
    if (!target || /^(https?:|mailto:|app:)/.test(target)) continue;
    target = decodeURIComponent(target);
    const full = resolve(root, dirname(path), target);
    check(full.startsWith(root + "/") && existsSync(full), path + ": missing/unsafe local link " + target);
  }
}
const issues = JSON.parse(read("docs/github/issues.json"));
const project = JSON.parse(read("docs/github/project.json"));
check(issues.length === 10, "Expected exactly ten initial issues");
check(new Set(issues.map(i => i.id)).size === 10, "Issue IDs must be unique");
const required = ["Goal", "Context", "Scope", "Out of scope", "Dependencies", "Technical constraints",
  "Security/privacy", "Acceptance criteria", "Unit test plan", "Integration test plan", "Physical-device test plan",
  "Failure-injection test plan", "Observability", "Definition of done", "Done when", "Story points",
  "Open / UNSPECIFIED questions", "Links to ADR/spec"];
for (const [n, issue] of issues.entries()) {
  check(issue.id === "KR-" + String(n + 1).padStart(3, "0"), "Issue order/ID mismatch");
  check([1,2,3,5,8,13].includes(issue.story_points), issue.id + ": non-Fibonacci points");
  const body = read(issue.body_file);
  for (const section of required) check(body.includes("## " + section + "\n"), issue.id + ": missing " + section);
  check((body.match(/- \[ \] AC-/g) ?? []).length >= 5, issue.id + ": insufficient acceptance criteria");
  for (const dep of issue.dependencies) check(issues.some(i => i.id === dep) && dep !== issue.id, issue.id + ": invalid dependency");
  for (const field of ["priority", "risk", "area", "platform", "status", "decision_required", "work_type"]) {
    const name = {priority:"Priority", risk:"Risk", area:"Area", platform:"Platform", status:"Status", decision_required:"Decision Required", work_type:"Work Type"}[field];
    check(project.fields.find(f => f.name === name)?.options.includes(issue[field]), issue.id + ": invalid " + field);
  }
  check(project.milestones.some(m => m.title === issue.milestone), issue.id + ": invalid milestone");
}
function visit(id, chain = []) {
  check(!chain.includes(id), "Dependency cycle: " + [...chain, id].join(" -> "));
  if (chain.includes(id)) return;
  for (const dep of issues.find(i => i.id === id).dependencies) visit(dep, [...chain, id]);
}
issues.forEach(i => visit(i.id));
const form = JSON.parse(read(".github/ISSUE_TEMPLATE/implementation.yml")); // JSON is YAML flow syntax.
for (const section of required) check(form.body.some(f => f.attributes?.label === section && f.validations?.required), "Form missing " + section);
check(new Set(form.body.filter(f => f.id).map(f => f.id)).size === form.body.filter(f => f.id).length, "Duplicate form IDs");
for (const path of files.filter(p => /^docs\/adr\/\d/.test(p))) {
  const body = read(path);
  for (const term of ["Goal", "Context", "Constraints", "Done when", "Alternatives", "Security/privacy", "Operational", "Decision", "reasons", "Risks", "invalidat"]) {
    check(body.toLowerCase().includes(term.toLowerCase()), path + ": missing ADR term " + term);
  }
}
const tokens = JSON.parse(read("docs/design/tokens.json"));
function luminance(hex) {
  return hex.slice(1).match(/../g).map(x => parseInt(x,16)/255)
    .map(x => x <= 0.04045 ? x/12.92 : ((x+0.055)/1.055)**2.4)
    .reduce((a,x,i) => a + x * [0.2126,0.7152,0.0722][i],0);
}
for (const [fg,bg] of [["ink","background"],["inkSecondary","surface"],["onPrimary","primary"],["pending","pendingContainer"],["error","errorContainer"]]) {
  const a = luminance(tokens.colours[fg]), b = luminance(tokens.colours[bg]);
  const ratio = (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);
  check(ratio >= 4.5, "Text contrast below 4.5: " + fg + "/" + bg);
}
for (const image of ["store-01-devices.png","store-02-add-time.png","store-03-no-surveillance.png"]) {
  const p = resolve(root,"docs/design/assets",image);
  check(existsSync(p), "Missing concept " + image);
  if (existsSync(p)) {
    const data = readFileSync(p);
    check(data.subarray(1,4).toString() === "PNG", "Not PNG: " + image);
    check(data.readUInt32BE(16) === 941 && data.readUInt32BE(20) === 1672, "Update documented concept dimensions: " + image);
  }
}
const workflow = read(".github/workflows/planning.yml");
check(/actions\/checkout@[a-f0-9]{40}/.test(workflow), "Checkout action needs full SHA");
check(workflow.includes("contents: read") && workflow.includes("persist-credentials: false"), "CI permissions/credentials changed");
check(!workflow.includes("pull_request_target"), "Unsafe trigger for planning checks");
if (errors.length) {
  errors.forEach(e => process.stderr.write(e + "\n"));
  process.exit(1);
}
process.stdout.write("Planning validation passed: local links, 10 issue contracts/dependencies, 7 ADRs, Issue Form, tokens and 3 concept assets.\n");
process.stdout.write("This does not run Android, database, physical-device, load or store-policy approval tests.\n");
