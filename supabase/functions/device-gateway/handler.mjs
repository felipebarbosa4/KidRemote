// KR-004 AC-5 local handler. No server/deployment entrypoint or credential issuance.
// Dependencies provide records/operation storage, never an allow/deny decision.
import { createHash, timingSafeEqual } from 'node:crypto';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const integer = n => Number.isSafeInteger(n) && n >= 0;
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const exact = (x, keys) => object(x) && Object.keys(x).length === keys.length && keys.every(k => Object.hasOwn(x,k));
const reply = (status, code, value) => Response.json(value ?? {code}, {
  status, headers: {'cache-control':'no-store','x-content-type-options':'nosniff'},
});
export const credentialDigest = secret => createHash('sha256').update(secret, 'utf8').digest('hex');

async function boundedJson(request) {
  if (request.headers.get('content-type')?.split(';')[0] !== 'application/json') return null;
  if (request.headers.has('content-length') && Number(request.headers.get('content-length')) > 65536) return null;
  if (!request.body) return null;
  const reader = request.body.getReader(), chunks = [];
  let count = 0;
  try {
    for (;;) {
      const {done,value} = await reader.read();
      if (done) break;
      count += value.byteLength;
      if (count > 65536) { await reader.cancel(); return null; }
      chunks.push(value);
    }
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch { return null; }
  finally { reader.releaseLock(); }
}

// withCredential must read current credential + device server-side, in the same
// transaction/snapshot used by its scoped storage methods; credential/device revocation
// must serialize with that transaction. KR-004 HTTP unit fixtures label storage as
// stubbed; KR-007 local-database.mjs supplies real transactions for initial reads only.
export function createDeviceHandler(repository, clock = () => Date.now()) {
  return async request => {
    try {
      const url = new URL(request.url);
      if (request.method !== 'POST' || url.search || !['/device/sync','/device/ack','/device/push-registration'].includes(url.pathname))
        return reply(404,'UNSUPPORTED_OPERATION');
      const authorization = request.headers.get('authorization') ?? '';
      // Existing opaque bearer contract; no parent JWT, API key or caller ID fallback.
      const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(authorization);
      if (!match || Buffer.from(match[1],'base64url').length !== 32 ||
          Buffer.from(match[1],'base64url').toString('base64url') !== match[1]) return reply(401,'UNAUTHORIZED');
      const digest = credentialDigest(match[1]);
      const body = await boundedJson(request);
      if (!object(body) || body.protocol_version !== 1) return reply(400,'INVALID_PAYLOAD');

      const response = await repository.withCredential(digest, async records => {
        const c = records?.credential, d = records?.device;
        // Credential verification precedes scope authorization and revocation response.
        if (!c || !/^[0-9a-f]{64}$/.test(c.secret_digest ?? '') ||
            !timingSafeEqual(Buffer.from(digest,'hex'),Buffer.from(c.secret_digest,'hex')))
          return reply(401,'UNAUTHORIZED');
        if (!d || !Object.hasOwn(c,'revoked_at') || !Object.hasOwn(d,'revoked_at') ||
            !UUID.test(c.credential_id) || !UUID.test(c.device_id) ||
            c.device_id !== d.id || !UUID.test(d.id) || !UUID.test(d.household_id) ||
            !UUID.test(d.policy_epoch)) return reply(401,'UNAUTHORIZED');
        if (c.revoked_at != null || d.revoked_at != null) return reply(403,'DEVICE_REVOKED');
        const expires = Date.parse(c.expires_at);
        if (!Number.isFinite(expires) || expires <= clock()) return reply(401,'UNAUTHORIZED');
        const scope = Object.freeze({credential_id:c.credential_id,device_id:d.id,
          household_id:d.household_id,policy_epoch:d.policy_epoch});

        if (url.pathname === '/device/sync') {
          if (!exact(body,['protocol_version','after_version']) || !integer(body.after_version))
            return reply(400,'INVALID_PAYLOAD');
          return reply(200,null,await records.sync(scope,{after_version:body.after_version}));
        }
        if (url.pathname === '/device/ack') {
          if (!exact(body,['protocol_version','command_id','policy_epoch','snapshot_version','outcome','observed_enforcement']) ||
              !UUID.test(body.command_id) || !UUID.test(body.policy_epoch) ||
              !integer(body.snapshot_version) ||
              !['persisted','applied','superseded','expired_for_period','failed','rejected'].includes(body.outcome) ||
              typeof body.observed_enforcement !== 'boolean') return reply(400,'INVALID_PAYLOAD');
          const command = await records.findCommand(body.command_id);
          // Siblings are foreign devices too; household equality alone is insufficient.
          if (!command || command.device_id !== scope.device_id || command.household_id !== scope.household_id)
            return reply(403,'TARGET_DENIED');
          if (body.policy_epoch !== scope.policy_epoch ||
              !integer(records.policy_version) || !integer(command.version) ||
              body.snapshot_version < command.version || body.snapshot_version > records.policy_version)
            return reply(409,'VERSION_CONFLICT');
          return reply(200,null,await records.ack(scope,{command_id:body.command_id,
            snapshot_version:body.snapshot_version,outcome:body.outcome,observed_enforcement:body.observed_enforcement}));
        }
        if (!exact(body,['protocol_version','provider','address_kind','address']) ||
            body.provider !== 'fcm' || !['fid','registration_token'].includes(body.address_kind) ||
            typeof body.address !== 'string' || !/^[A-Za-z0-9_:\-]{1,4096}$/.test(body.address))
          return reply(400,'INVALID_PAYLOAD');
        const owner = await records.findPushOwner(body.provider,body.address);
        if (owner && owner.device_id !== scope.device_id) return reply(409,'ADDRESS_CONFLICT');
        return reply(200,null,await records.registerPush(scope,{provider:body.provider,
          address_kind:body.address_kind,address:body.address}));
      });
      return response instanceof Response ? response : reply(503,'TEMPORARILY_UNAVAILABLE');
    } catch {
      // Never log raw request, bearer, SQL error, dependency exception or provider address.
      return reply(503,'TEMPORARILY_UNAVAILABLE');
    }
  };
}
