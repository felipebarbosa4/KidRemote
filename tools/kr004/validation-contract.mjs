// AC-7: partial suite discovery must never be reported as complete KR-004 validation.
export const localEndpoints = ['unix:///var/run/docker.sock','npipe:////./pipe/dockerDesktopLinuxEngine'];
export const requiredMigrations = ['202609110001_schema_rls.sql','202609110002_atomic_control.sql','202609110003_pairing.sql','202609110004_parent_household.sql','202609120001_rotation.sql'];
export const requiredSuites = ['01_rls.test.sql','02_constraints.test.sql','03_atomic_control.test.sql','04_concurrent_control.test.sql','05_pairing.test.sql','06_pairing_races.test.sql','07_parent_bootstrap.test.sql','08_rotation.test.sql'];
export function requireInventory(migrations, suites) {
  if (requiredMigrations.some(f => !migrations.includes(f)) || requiredSuites.some(f => !suites.includes(f)))
    throw new Error('REQUIRED_KR004_VALIDATION_INPUT_MISSING');
}
