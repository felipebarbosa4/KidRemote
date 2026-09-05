import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

function derived(state) {
  const remaining = Math.max(0, state.daily_limit_seconds + state.bonus_seconds - state.used_seconds);
  const policyBlocked = state.manual_lock || remaining === 0;
  const reasons = [];
  if (state.manual_lock) reasons.push("MANUAL_LOCK");
  if (remaining === 0) reasons.push("TIME_EXPIRED");
  if (state.accounting_uncertain) reasons.push("ACCOUNTING_UNCERTAIN");
  if (state.setup_incomplete) reasons.push("SETUP_INCOMPLETE");
  return {
    daily_limit_seconds: state.daily_limit_seconds,
    bonus_seconds: state.bonus_seconds,
    used_seconds: state.used_seconds,
    manual_lock: state.manual_lock,
    period_key: state.period_key,
    version: state.version,
    accounting_uncertain: state.accounting_uncertain,
    remaining_seconds: remaining,
    policy_blocked: policyBlocked,
    restriction_required: policyBlocked || state.accounting_uncertain || state.setup_incomplete,
    block_reasons: reasons
  };
}

function applyCase(testCase, constants) {
  const state = {
    accounting_uncertain: false,
    setup_incomplete: false,
    ...testCase.initial
  };
  const seenOperations = new Set();
  const results = [];

  for (const operation of testCase.operations) {
    const stale = "server_sequence" in operation && operation.server_sequence <= state.version;
    switch (operation.kind) {
      case "LOCK":
      case "UNLOCK": {
        if (stale) {
          results.push("stale_ignored");
          break;
        }
        state.manual_lock = operation.kind === "LOCK";
        state.version = operation.server_sequence;
        results.push("applied");
        break;
      }
      case "SET_DAILY_LIMIT": {
        if (stale) {
          results.push("stale_ignored");
          break;
        }
        if (!Number.isInteger(operation.seconds) || operation.seconds < 0 || operation.seconds > constants.maximum_daily_allowance_seconds) {
          results.push("rejected_limit");
          break;
        }
        state.daily_limit_seconds = operation.seconds;
        state.version = operation.server_sequence;
        results.push("applied");
        break;
      }
      case "ADD_TIME": {
        if (seenOperations.has(operation.operation_id)) {
          results.push("duplicate_ignored");
          break;
        }
        if (!constants.add_time_values_seconds.includes(operation.seconds)) {
          results.push("rejected_value");
          break;
        }
        if (stale) {
          results.push("stale_ignored");
          break;
        }
        if (operation.period_key !== state.period_key) {
          seenOperations.add(operation.operation_id);
          state.version = operation.server_sequence;
          results.push("expired_for_period");
          break;
        }
        if (state.daily_limit_seconds + state.bonus_seconds + operation.seconds > constants.maximum_daily_allowance_seconds) {
          results.push("rejected_cap");
          break;
        }
        seenOperations.add(operation.operation_id);
        state.bonus_seconds += operation.seconds;
        state.version = operation.server_sequence;
        results.push("applied");
        break;
      }
      case "RESET_DAY": {
        if (!operation.trusted) {
          state.accounting_uncertain = true;
          results.push("clock_uncertain");
        } else if (operation.period_key === state.period_key) {
          results.push("same_period_ignored");
        } else {
          state.period_key = operation.period_key;
          state.used_seconds = 0;
          state.bonus_seconds = 0;
          state.accounting_uncertain = false;
          results.push("reset_applied");
        }
        break;
      }
      case "COUNT_USAGE": {
        const current = derived(state);
        if (operation.eligible && !current.restriction_required) {
          state.used_seconds += operation.seconds;
          results.push("counted");
        } else {
          results.push("not_counted");
        }
        break;
      }
      case "OFFLINE_REBOOT":
        state.accounting_uncertain = true;
        results.push("clock_uncertain");
        break;
      case "MARK_ACCOUNTING_UNCERTAIN":
        state.accounting_uncertain = true;
        results.push("accounting_uncertain");
        break;
      default:
        throw new Error(testCase.id + ": unknown operation " + operation.kind);
    }
  }
  return {...derived(state), results};
}

export function validateStateFixtureDocument(fixtures, matrix) {
  const errors = [];
  if (fixtures.schema_version !== 1) errors.push("State fixture schema_version must be 1");
  if (fixtures.approval?.date !== "2026-09-05") errors.push("State fixtures need recorded owner approval date");
  if (!fixtures.model?.includes("absolute bonus")) errors.push("State fixtures must distinguish canonical grants from child absolute-bonus merge");
  if (!Array.isArray(fixtures.cases) || fixtures.cases.length < 12) errors.push("State fixtures need at least 12 cases");
  const ids = new Set();
  for (const testCase of fixtures.cases ?? []) {
    if (ids.has(testCase.id)) errors.push("Duplicate state fixture ID: " + testCase.id);
    ids.add(testCase.id);
    for (const testId of testCase.test_ids ?? []) {
      if (!matrix.includes("| " + testId + " |")) errors.push(testCase.id + ": unknown matrix test " + testId);
    }
    let actual;
    try {
      actual = applyCase(testCase, fixtures.constants);
    } catch (error) {
      errors.push(error.message);
      continue;
    }
    if (JSON.stringify(actual) !== JSON.stringify(testCase.expected)) {
      errors.push(testCase.id + ": expected " + JSON.stringify(testCase.expected) + " but got " + JSON.stringify(actual));
    }
  }
  for (const required of [
    "unlock-clears-manual-only-at-zero",
    "distinct-additions-and-transport-retry",
    "daily-reset-retains-manual-lock",
    "late-grant-does-not-credit-today",
    "offline-reboot-withholds-new-day-credit",
    "daily-allowance-cap-rejects-excess"
  ]) {
    if (!ids.has(required)) errors.push("Missing required state fixture: " + required);
  }
  return errors;
}

export function validateStateFixtures(root) {
  const path = resolve(root, "docs/product-specs/STATE-MACHINE-CASES.json");
  const fixtures = JSON.parse(readFileSync(path, "utf8"));
  const matrix = readFileSync(resolve(root, "docs/test-plans/MATRIX.md"), "utf8");
  return validateStateFixtureDocument(fixtures, matrix);
}

const invoked = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
  const errors = validateStateFixtures(root);
  if (errors.length) {
    for (const error of errors) process.stderr.write(error + "\n");
    process.exit(1);
  }
  process.stdout.write("Approved state-machine fixtures passed.\n");
}
