import { i as __toESM } from "../_runtime.mjs";
import { U as isRedirect, b as require_jsx_runtime, q as require_react, y as useRouter } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as TSS_SERVER_FUNCTION, r as getServerFnById, t as createServerFn } from "./ssr.mjs";
import { i as FileDown, n as Layers, r as FolderX } from "../_libs/lucide-react.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/routes-G24wtLcr.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function useServerFn(serverFn) {
	const router = useRouter();
	return import_react.useCallback(async (...args) => {
		try {
			const res = await serverFn(...args);
			if (isRedirect(res)) throw res;
			return res;
		} catch (err) {
			if (isRedirect(err)) {
				err.options._fromLocation = router.stores.location.get();
				return router.navigate(router.resolveRedirect(err).options);
			}
			throw err;
		}
	}, [router, serverFn]);
}
var createSsrRpc = (functionId) => {
	const url = "/_serverFn/" + functionId;
	const serverFnMeta = { id: functionId };
	const fn = async (...args) => {
		return (await getServerFnById(functionId, { origin: "server" }))(...args);
	};
	return Object.assign(fn, {
		url,
		serverFnMeta,
		[TSS_SERVER_FUNCTION]: true
	});
};
var dryRunAscension = createServerFn({ method: "POST" }).handler(createSsrRpc("59ac14cb6e4e92ea910d88c33f521620d044f1c21221e09aa3f704d1096a6d6b"));
var PLAN = `ascension
installs Lecram's DLSS 5 for AION 2
writes nothing inside the game folder

  1. DLSS5VKLayer under ~/.local
  2. nvngx_dlssnr.dll into the helper, not the game
  3. Steam app 3393110 gets VKLayer_DLSS5=1 %command%`;
function Home() {
	const runDry = useServerFn(dryRunAscension);
	const [log, setLog] = (0, import_react.useState)(PLAN);
	const [phase, setPhase] = (0, import_react.useState)("idle");
	async function onDryRun() {
		setPhase("run");
		try {
			const result = await runDry();
			setLog(result.output || "Dry-run finished with no output.");
			setPhase("done");
		} catch (err) {
			const message = err instanceof Error ? err.message : "Dry-run failed.";
			setLog(message);
			setPhase("error");
		}
	}
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("main", {
		className: "min-h-dvh bg-bg text-ink",
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "mx-auto flex w-full max-w-2xl flex-col px-5 py-10 sm:px-8 sm:py-14",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-xs font-medium tracking-widest text-gold uppercase",
					children: "Linux · AION 2"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
					className: "mt-3 font-display text-5xl leading-none text-ink sm:text-6xl",
					children: "Ascension"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-4 max-w-prose text-base leading-relaxed text-muted",
					children: "One command installs Lecram's DLSS 5 mod through the DLSS5 Vulkan layer. The AION 2 folder is not touched, so the file check has nothing new to find."
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ol", {
					className: "mt-8 border-y border-line",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Step, {
							n: "01",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(FolderX, {
								className: "size-5",
								"aria-hidden": "true"
							}),
							title: "Game folder stays stock",
							detail: "No DLL, ReShade, or addon next to the executable."
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Step, {
							n: "02",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Layers, {
								className: "size-5",
								"aria-hidden": "true"
							}),
							title: "Layer lives in your home directory",
							detail: "DLSS5VKLayer and the helper stay under ~/.local. Steam only gets an environment variable on AION 2."
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Step, {
							n: "03",
							icon: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(FileDown, {
								className: "size-5",
								"aria-hidden": "true"
							}),
							title: "You supply Lecram's DLL",
							detail: "Drop nvngx_dlssnr.dll into ~/.local/share/ascension/import or Downloads. Ascension does not download it."
						})
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-8 flex flex-col gap-3 sm:flex-row",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
						href: "/api/ascension",
						download: "ascension",
						className: "inline-flex h-12 cursor-pointer items-center justify-center bg-gold px-5 text-sm font-semibold text-gold-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold",
						children: "Download Ascension"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
						type: "button",
						onClick: onDryRun,
						disabled: phase === "run",
						className: "inline-flex h-12 items-center justify-center border border-line bg-raise px-5 text-sm font-medium text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold disabled:opacity-60",
						children: phase === "run" ? "Running dry-run…" : "Dry-run the plan"
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
					className: "mt-3 text-sm leading-relaxed text-muted",
					children: [
						"On the Linux PC where AION 2 is installed, run",
						" ",
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-ink",
							children: "bash ascension"
						}),
						". No window. Quit Steam fully once so the launch option sticks, then start the game from Steam. Needs Proton-GE, Proton-CachyOS, Wine-GE, or system Wine — not official Proton."
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("aside", {
					className: "mt-8 border border-line bg-raise p-4",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "text-xs font-semibold tracking-widest text-clay uppercase",
						children: "Not an anti-cheat bypass"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-2 text-sm leading-relaxed text-ink",
						children: [
							"Ascension does not disable NC Guard, hide from it, or patch it. It only keeps the mod out of the game folder. The Vulkan layer still loads in the game process. Undo with",
							" ",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-gold",
								children: "ascension --remove"
							}),
							"."
						]
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
					className: "mt-6 border border-line bg-raise",
					"aria-live": "polite",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "border-b border-line px-4 py-2 text-xs tracking-widest text-muted uppercase",
						children: phase === "done" ? "Dry-run on an empty demo account" : "What the command does"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("pre", {
						className: "max-h-80 overflow-auto px-4 py-4 text-sm leading-relaxed break-all whitespace-pre-wrap text-ink",
						children: log
					})]
				})
			]
		})
	});
}
function Step({ n, icon, title, detail }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
		className: "flex gap-4 border-b border-line py-4 last:border-b-0",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
			className: "w-8 shrink-0 font-display text-lg text-gold",
			children: n
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "min-w-0",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
				className: "flex items-center gap-2 text-base font-medium text-ink",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-gold",
					children: icon
				}), title]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "mt-1 text-sm leading-relaxed text-muted",
				children: detail
			})]
		})]
	});
}
//#endregion
export { Home as component };
