// AC-7: partial suite discovery must never be reported as complete KR-004 validation.
export const localEndpoints = ['unix:///var/run/docker.sock','npipe:////./pipe/dockerDesktopLinuxEngine'];
export const requiredMigrations = ['202609110001_schema_rls.sql','202609110002_atomic_control.sql'];
export const requiredSuites = ['01_rls.test.sql','02_constraints.test.sql','03_atomic_control.test.sql','04_concurrent_control.test.sql'];
export function requireInventory(migrations, suites) {
  if (requiredMigrations.some(f => !migrations.includes(f)) || requiredSuites.some(f => !suites.includes(f)))
    throw new Error('REQUIRED_KR004_VALIDATION_INPUT_MISSING');
}
