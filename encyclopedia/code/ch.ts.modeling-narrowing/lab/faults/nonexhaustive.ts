// Responsibility: inject a newly added cancelled state without updating the exhaustive renderer.
// Data source: the local LoadState declaration is the complete compile-time fixture.
// Mapping: each handled status maps to text while cancelled remains at the never assignment.
// Side effects: none; this file is expected to fail static compilation with TS2322.

type LoadState =
  | { status: "idle" }
  | { status: "ready"; id: string }
  | { status: "cancelled"; reason: string };

function render(state: LoadState): string {
  switch (state.status) {
    case "idle":
      return "idle";
    case "ready":
      return state.id;
    default: {
      const exhaustive: never = state;
      return exhaustive;
    }
  }
}

void render;
