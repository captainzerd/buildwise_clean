// functions/src/aiCostOptimiser.ts
//
// HTTPS callable Cloud Function that uses the Claude API to analyse a
// construction estimate and return cost-optimisation suggestions.
//
// Secret setup (run once):
//   firebase functions:secrets:set ANTHROPIC_API_KEY
// Deploy:
//   cd functions && npm run build && firebase deploy --only functions:analyseEstimateCosts

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import Anthropic from "@anthropic-ai/sdk";

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

interface EstimateInput {
  typology: string; // e.g. "Residential Standard"
  quality: string; // "Economy" | "Standard" | "Premium"
  region: string; // e.g. "Greater Accra"
  floorAreaM2: number;
  floors: number;
  totalGhs: number;
  breakdownGhs: Record<string, number>; // phase → GHS amount
  preliminariesPct: number;
  ohpPct: number;
  contingencyPct: number;
}

export const analyseEstimateCosts = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
    secrets: [anthropicApiKey],
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated.");
    }

    const data = request.data as EstimateInput;

    if (!data.totalGhs || data.totalGhs <= 0) {
      throw new HttpsError("invalid-argument", "Invalid estimate data.");
    }

    const client = new Anthropic({
      apiKey: anthropicApiKey.value(),
    });

    const prompt = `You are an expert construction cost consultant for Ghana. Analyse this building estimate and provide 4–6 specific, actionable cost optimisation suggestions.

## Project Details
- Building type: ${data.typology}
- Quality tier: ${data.quality}
- Region: ${data.region}
- Floor area: ${data.floorAreaM2.toFixed(0)} m²
- Floors: ${data.floors}
- Total estimated cost: GHS ${data.totalGhs.toLocaleString("en-GH", { minimumFractionDigits: 2 })}

## Cost Breakdown by Phase
${Object.entries(data.breakdownGhs)
  .sort((a, b) => b[1] - a[1])
  .map(
    ([phase, ghs]) =>
      `- ${phase}: GHS ${ghs.toLocaleString("en-GH", { minimumFractionDigits: 2 })} (${((ghs / data.totalGhs) * 100).toFixed(1)}%)`,
  )
  .join("\n")}

## Current Percentages
- Preliminaries: ${data.preliminariesPct}%
- Overhead & Profit: ${data.ohpPct}%
- Contingency: ${data.contingencyPct}%

Respond with a JSON object in this exact format:
{
  "headline": "Brief summary of total potential savings (e.g. 'Up to GHS 45,000 in savings identified')",
  "suggestions": [
    {
      "title": "Short title",
      "description": "Specific actionable advice referencing Ghana market context",
      "potentialSavingPct": 5.0,
      "category": "Materials | Specification | Design | Programme | Procurement"
    }
  ]
}

Focus on:
1. Material specification downgrades (e.g. local vs imported tiles)
2. Structural efficiency (e.g. roof type, foundation type for soil class)
3. Ghana-specific procurement tips (e.g. bulk buying cement bags, local quarry aggregates)
4. Design optimisations (e.g. floor plan efficiency ratio)
5. Programme phasing to reduce cash-flow burden
6. Contractor market conditions in the specified region

Keep descriptions concise (2–3 sentences). Only respond with valid JSON, no markdown.`;

    try {
      const message = await client.messages.create({
        model: "claude-haiku-4-5",
        max_tokens: 1024,
        messages: [{ role: "user", content: prompt }],
      });

      const textBlock = message.content.find((b) => b.type === "text");
      if (!textBlock || textBlock.type !== "text") {
        throw new HttpsError("internal", "No response from AI.");
      }

      const result = JSON.parse(textBlock.text);
      return result;
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError(
        "internal",
        `AI analysis failed: ${(e as Error).message}`,
      );
    }
  },
);
