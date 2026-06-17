import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const { text } = await req.json() as { text: string };
    const apiKey = Deno.env.get("GEMINI_KEY");

    if (!apiKey) {
      return new Response(JSON.stringify({ error: "GEMINI_KEY not configured" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const response = await fetch(GEMINI_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {
                text:
                  "Extract medicine information from this text. Return ONLY a JSON array with these keys: 'name', 'dosage', 'frequency' (1, 2, or 3), 'time1' (e.g. 08:00 AM), 'time2' (if frequency > 1), 'time3' (if frequency > 2), 'duration_days' (integer), 'qty' (total pills). Text: " +
                  text,
              },
            ],
          },
        ],
      }),
    });

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});