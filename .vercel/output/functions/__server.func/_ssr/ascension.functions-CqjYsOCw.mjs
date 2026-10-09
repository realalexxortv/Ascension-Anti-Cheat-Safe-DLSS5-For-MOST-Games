import { n as TSS_SERVER_FUNCTION, t as createServerFn } from "./ssr.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/ascension.functions-CqjYsOCw.js
var createServerRpc = (serverFnMeta, splitImportFn) => {
	const url = "/_serverFn/" + serverFnMeta.id;
	return Object.assign(splitImportFn, {
		url,
		serverFnMeta,
		[TSS_SERVER_FUNCTION]: true
	});
};
var dryRunAscension_createServerFn_handler = createServerRpc({
	id: "59ac14cb6e4e92ea910d88c33f521620d044f1c21221e09aa3f704d1096a6d6b",
	name: "dryRunAscension",
	filename: "src/lib/ascension.functions.ts"
}, (opts) => dryRunAscension.__executeServer(opts));
var dryRunAscension = createServerFn({ method: "POST" }).handler(dryRunAscension_createServerFn_handler, async () => {
	const { spawn } = await import("node:child_process");
	const { tmpdir } = await import("node:os");
	const script = (await import("./ascension-cFJRo0Po.mjs").then((n) => n.n)).default;
	return { output: await new Promise((resolve, reject) => {
		const child = spawn("bash", [
			"-s",
			"--",
			"--dry-run"
		], { env: {
			PATH: process.env.PATH ?? "/usr/bin:/bin",
			HOME: "/home/you",
			LANG: "C.UTF-8",
			TMPDIR: tmpdir()
		} });
		let text = "";
		const take = (buf) => {
			if (text.length < 2e4) text += buf.toString("utf8");
		};
		child.stdout.on("data", take);
		child.stderr.on("data", take);
		const timer = setTimeout(() => child.kill("SIGKILL"), 15e3);
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
	}) };
});
//#endregion
export { dryRunAscension_createServerFn_handler };
