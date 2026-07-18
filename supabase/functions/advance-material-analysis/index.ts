import { serve } from "serve";
import { createAnalysisDependencies } from "../_shared/material_analysis/edge_runtime.ts";
import {
  createMaterialAnalysisDispatchHandler,
} from "../_shared/material_analysis/handlers.ts";

serve((request) => {
  const jwt = bearer(request);
  try {
    const dependencies = createAnalysisDependencies(jwt);
    return createMaterialAnalysisDispatchHandler(dependencies)(request);
  } catch (_) {
    return unavailable();
  }
});

function bearer(request: Request) {
  const value = request.headers.get("Authorization") ?? "";
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}
function unavailable() {
  return new Response(
    JSON.stringify({ error: "Material analysis is temporarily unavailable." }),
    {
      status: 500,
      headers: { "Content-Type": "application/json" },
    },
  );
}
