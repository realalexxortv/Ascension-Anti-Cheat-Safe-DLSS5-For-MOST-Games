import { createFileRoute } from "@tanstack/react-router";
import script from "../../installer/ascension.sh?raw";

export const Route = createFileRoute("/api/ascension")({
  server: {
    handlers: {
      GET: async () =>
        new Response(script, {
          headers: {
            "Content-Type": "text/x-shellscript; charset=utf-8",
            "Content-Disposition": 'attachment; filename="ascension"',
            "Cache-Control": "no-cache",
          },
        }),
    },
  },
});
