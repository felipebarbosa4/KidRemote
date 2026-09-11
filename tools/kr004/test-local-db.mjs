#!/usr/bin/env node
// Local-only KR-004 runner. No remote targets, published ports, credentials in argv/logs,
// shared volumes, reset command, Docker prune or arbitrary existing-container target.
import { spawnSync } from 'node:child_process';
import { randomUUID, randomBytes } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { localEndpoints, requireInventory } from './validation-contract.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const options = process.argv.slice(2);
const docker = options[0] ?? 'docker';
const host = options[1] ?? 'unix:///var/run/docker.sock';
if (options.length > 3 || (options.length===3 && !['--pairing','--parent-test','--parent-dev','--parent-runtime','--enrollment-test','--enrollment-runtime','--enrollment-dev'].includes(options[2])) || !localEndpoints.includes(host))
  throw new Error('Only the explicit local Unix socket or Docker Desktop Linux named pipe is allowed');
const image = 'supabase/postgres:17.6.1.136@sha256:f371b5f3f2ac0a05703f33d6e6134515fb2498cab708fb948a0aeb7481467c00';
const token = randomUUID();
const name = 'kr004-ac14-' + token;
const label = 'org.kidremote.kr004.disposable';
const env = { ...process.env, POSTGRES_PASSWORD: randomBytes(32).toString('hex') };
// The explicit local endpoint must not inherit a remote context/TLS override.
for (const key of ['DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH']) delete env[key];
// Process-scoped WSL-to-Windows environment forwarding, not a host/integration change.
// Native docker.exe reads the value for '-e POSTGRES_PASSWORD'; never put it in argv.
if (docker.endsWith('.exe')) env.WSLENV = [process.env.WSLENV, 'POSTGRES_PASSWORD/w'].filter(Boolean).join(':');
let id, verified = false, primary, networkId;
const parentMode=options[2]?.startsWith('--parent-') || options[2]?.startsWith('--enrollment-');
const network=parentMode ? name+'-network' : 'none';
function inspectNetwork() {
  const n=JSON.parse(call(['network','inspect',networkId]))[0];
  if(n.Id!==networkId || n.Name!==network || n.Labels[label]!==token || n.Driver!=='bridge' ||
      n.Options['com.docker.network.bridge.host_binding_ipv4']!=='127.0.0.1' ||
      n.Options['com.docker.network.bridge.enable_ip_masquerade']!=='false')
    throw Error('TASK_NETWORK_NOT_VERIFIED');
}
function call(args, input, allowFailure = false) {
  const r = spawnSync(docker, ['--host', host, ...args], {
    input, encoding: 'utf8', env, timeout: 180000, maxBuffer: 8 * 1024 * 1024,
  });
  if (r.error || r.status !== 0) {
    if (allowFailure) return null;
    // Deliberately no raw Docker/Postgres stderr: may echo a failing SQL tuple.
    const state = r.stderr?.match(/(?:ERROR|FATAL):\s+([0-9A-Z]{5})\b/)?.[1] ?? 'UNSPECIFIED';
    const line = r.stderr?.match(/<stdin>:(\d+):/)?.[1] ?? 'UNSPECIFIED';
    const completed = r.stdout?.split(/\r?\n/).filter(l => /^(?:not )?ok \d+ - /.test(l)) ?? [];
    if (completed.length) console.error('LAST_DATABASE_ASSERTION=' + completed.at(-1));
    throw new Error('LOCAL_DB_COMMAND_FAILED:' + args[0] + ':exit=' + r.status + ':sqlstate=' + state + ':line=' + line);
  }
  return (args[0]==='logs' ? r.stdout+r.stderr : r.stdout).trim();
}
function inspect() {
  const record = JSON.parse(call(['inspect', id]))[0];
  if (record.Id !== id || record.Name !== '/' + name ||
      record.Config.Labels[label] !== token || record.Config.Image !== image ||
      record.HostConfig.NetworkMode !== network ||
      Object.keys(record.HostConfig.PortBindings ?? {}).length !== 0 ||
      (record.Mounts ?? []).some(m => m.Type !== 'tmpfs'))
    throw new Error('DISPOSABLE_IDENTITY_NOT_VERIFIED');
  return record;
}
function sql(input) {
  return call(['exec', '-i', id, 'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=sqlstate',
    '-U', 'supabase_admin', '-d', 'postgres'], input);
}
try {
  const migrations = readdirSync(resolve(root, 'supabase/migrations')).filter(f => /^\d+.*\.sql$/.test(f)).sort();
  const suites = readdirSync(resolve(root, 'supabase/tests')).filter(f => f.endsWith('.test.sql')).sort();
  requireInventory(migrations, suites);
  if (call(['info', '--format', '{{.OSType}}']) !== 'linux') throw new Error('LOCAL_LINUX_REQUIRED');
  if(parentMode) {
    networkId=call(['network','create','--driver','bridge',
      '--opt','com.docker.network.bridge.host_binding_ipv4=127.0.0.1',
      '--opt','com.docker.network.bridge.enable_ip_masquerade=false','--label',label+'='+token,network]);
    inspectNetwork();
  }
  // create never reuses a name; tmpfs and network=none bound all task data.
  id = call(['create', '--name', name, '--label', label + '=' + token,
    '--network', network, '--restart', 'no', '--tmpfs', '/var/lib/postgresql/data:rw',
    '-e', 'POSTGRES_PASSWORD', image]);
  if (!/^[0-9a-f]{64}$/.test(id)) throw new Error('INVALID_ALLOCATED_ID');
  const record = inspect();
  verified = true;
  console.log(JSON.stringify({ stage: 'ALLOCATED_AND_VERIFIED', container: id, name,
    database: 'postgres', endpoint: host, image: record.Config.Image,
    network, publishedPorts: 0, data: 'task-owned tmpfs' }));
  call(['start', id]);
  let ready = false;
  for (let i = 0; i < 90; i++) {
    if (!inspect().State.Running) throw new Error('DATABASE_CONTAINER_EXITED_DURING_INIT');
    // pg_isready alone can see the temporary init server before its shutdown.
    const initialized = call(['logs', id]).includes('PostgreSQL init process complete; ready for start up.');
    const status = initialized ? call(['exec', id, 'pg_isready', '-U', 'supabase_admin', '-d', 'postgres'], undefined, true) : null;
    if (status?.includes('accepting connections')) { ready = true; break; }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  }
  if (!ready) throw new Error('DATABASE_START_TIMEOUT');
  if (sql("select to_regprocedure('auth.uid()') is not null;") !== 't')
    throw new Error('SUPABASE_AUTH_DATABASE_PREREQUISITE_MISSING');
  const identity = sql("select current_database() || ':' || current_user; select count(*) from pg_tables where schemaname in ('public','private');");
  if (identity !== 'postgres:supabase_admin\n0') throw new Error('EMPTY_APPLICATION_DATABASE_REQUIRED');
  console.log('EMPTY_APPLICATION_DATABASE_VERIFIED');
  console.log('POSTGRES_VERSION=' + sql('show server_version;'));
  console.log('PGTAP_AVAILABLE=' + sql("select exists(select 1 from pg_available_extensions where name='pgtap');"));
  for (const f of migrations) {
    console.log('MIGRATION_START=' + f);
    sql(readFileSync(resolve(root, 'supabase/migrations', f), 'utf8'));
    console.log('MIGRATION_PASS=' + f);
  }
  if (suites.length === 0) throw new Error('DATABASE_TEST_SUITE_MISSING');
  for (const f of suites) {
    console.log('DATABASE_TEST_START=' + f);
    const result = sql(readFileSync(resolve(root, 'supabase/tests', f), 'utf8'));
    const lines = result.split(/\r?\n/);
    const tests = lines.filter(l => /^ok \d+/.test(l));
    const failed = lines.filter(l => /^not ok \d+/.test(l));
    const plan = lines.find(l => /^1\.\.\d+$/.test(l));
    if (failed.length || !plan || tests.length === 0 || tests.length !== Number(plan.slice(3)) ||
        tests.some((l, i) => !l.startsWith('ok ' + (i + 1) + ' ') || /#\s*(SKIP|TODO)\b/i.test(l))) {
      console.log(failed.join('\n'));
      throw new Error('DATABASE_TEST_FAILURE:' + f);
    }
    console.log('DATABASE_TEST_PASS=' + f + ':assertions=' + tests.length);
  }
  if (options[2]==='--pairing' || parentMode) {
    const { runPairingIntegration } = await import('../kr005/database-protocol.mjs');
    await runPairingIntegration(sql,()=>call(['logs',id]));
  }
  if(parentMode) {
    const {runParentAuth}=await import('../kr006/local-auth.mjs');
    await runParentAuth({sql,call,env,name,label,token,network,databaseHost:name,
      windows:docker.endsWith('.exe'),keep:['--parent-dev','--enrollment-dev'].includes(options[2]),runtime:options[2]==='--parent-runtime',
      enrollment:options[2]?.startsWith('--enrollment-'),enrollmentRuntime:options[2]==='--enrollment-runtime',gatewayConfig:{docker,host,container:id,label,owner:token}});
  }
} catch (error) {
  primary = error;
  console.error(error.message);
} finally {
  if (id && verified) {
    try {
      inspect(); // exact target and ownership must still match before removal
      call(['rm', '-f', id]); // removes only this task's synthetic DB/tmpfs
      if (call(['container', 'ls', '-a', '--filter', 'id=' + id, '--format', '{{.ID}}']) !== '')
        throw new Error('CONTAINER_REMOVAL_NOT_VERIFIED');
      console.log('CLEANUP=VERIFIED_TASK_CONTAINER_REMOVED');
    } catch (error) {
      console.error('CLEANUP_FAILED:task-container=' + id);
      primary ??= error; // never replace the original migration/test failure
    }
  } else if (id) {
    console.error('CLEANUP_NOT_AUTHORIZED:unverified-allocated-container=' + id);
  }
  if(networkId) {
    try { inspectNetwork(); call(['network','rm',networkId]); console.log('TASK_NETWORK_REMOVED'); }
    catch(error) { primary??=error; console.error('TASK_NETWORK_CLEANUP_FAILED'); }
  }
}
if (primary) process.exitCode = 1;
