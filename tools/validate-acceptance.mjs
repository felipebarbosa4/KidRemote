// Completion does not remove an acceptance criterion from the issue contract.
export function countAcceptanceCriteria(body) {
  return (body.match(/^- \[[ x]\] AC-\d+:/gm) ?? []).length;
}
