export type CoreDecision = {
  route: "deterministic" | "fast_ai" | "deep_reasoning" | "human_review";
  modelId: string | null;
  reason: string[];
  humanGate: boolean;
  auditRequired: boolean;
};

export async function routeNavegaIATask(task: string, opts: {
  risk?: "low" | "medium" | "high" | "critical";
  requiresEvidence?: boolean;
  requiresVision?: boolean;
  confidence?: number;
} = {}): Promise<CoreDecision | null> {
  const base = process.env.STARDESIGN_AI_CORE_URL?.replace(/\/$/, "");
  if (!base) return null;
  const r = await fetch(`${base}/v1/route`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ app: "navegaia", task, ...opts }),
  });
  if (!r.ok) throw new Error(`AI Core route failed: ${r.status}`);
  return r.json() as Promise<CoreDecision>;
}
