import { createServerFn } from "@tanstack/react-start";

export const dryRunAscension = createServerFn({ method: "POST" }).handler(async () => {
  const { spawn } = await import("node:child_process");
  const { tmpdir } = await import("node:os");
  const scriptMod = await import("../installer/ascension.sh?raw");
  const script = scriptMod.default;

  const output = await new Promise<string>((resolve, reject) => {
    const child = spawn("bash", ["-s", "--", "--dry-run"], {
      env: {
        PATH: process.env.PATH ?? "/usr/bin:/bin",
        HOME: "/home/you",
        LANG: "C.UTF-8",
        TMPDIR: tmpdir(),
      },
    });
    let text = "";
    const take = (buf: Buffer) => {
      if (text.length < 20000) text += buf.toString("utf8");
    };
    child.stdout.on("data", take);
    child.stderr.on("data", take);
    const timer = setTimeout(() => child.kill("SIGKILL"), 15000);
    child.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    child.on("close", () => {
      clearTimeout(timer);
      resolve(text.trim());
    });
    child.stdin.write(script);
    child.stdin.end();
  });
  return { output };
});