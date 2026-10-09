import { createFileRoute } from "@tanstack/react-router";
import { useServerFn } from "@tanstack/react-start";
import { useState, type ReactNode } from "react";
import { FileDown, FolderX, Layers } from "lucide-react";
import { dryRunAscension } from "@/lib/ascension.functions";

export const Route = createFileRoute("/")({ component: Home });

const PLAN = `ascension
installs Lecram's DLSS 5 for AION 2
writes nothing inside the game folder

  1. DLSS5VKLayer under ~/.local
  2. nvngx_dlssnr.dll into the helper, not the game
  3. Steam app 3393110 gets VKLayer_DLSS5=1 %command%`;

function Home() {
  const runDry = useServerFn(dryRunAscension);
  const [log, setLog] = useState(PLAN);
  const [phase, setPhase] = useState<"idle" | "run" | "done" | "error">("idle");

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

  return (
    <main className="min-h-dvh bg-bg text-ink">
      <div className="mx-auto flex w-full max-w-2xl flex-col px-5 py-10 sm:px-8 sm:py-14">
        <p className="text-xs font-medium tracking-widest text-gold uppercase">
          Linux · AION 2
        </p>
        <h1 className="mt-3 font-display text-5xl leading-none text-ink sm:text-6xl">
          Ascension
        </h1>
        <p className="mt-4 max-w-prose text-base leading-relaxed text-muted">
          One command installs Lecram's DLSS 5 mod through the DLSS5 Vulkan
          layer. The AION 2 folder is not touched, so the file check has nothing
          new to find.
        </p>

        <ol className="mt-8 border-y border-line">
          <Step
            n="01"
            icon={<FolderX className="size-5" aria-hidden="true" />}
            title="Game folder stays stock"
            detail="No DLL, ReShade, or addon next to the executable."
          />
          <Step
            n="02"
            icon={<Layers className="size-5" aria-hidden="true" />}
            title="Layer lives in your home directory"
            detail="DLSS5VKLayer and the helper stay under ~/.local. Steam only gets an environment variable on AION 2."
          />
          <Step
            n="03"
            icon={<FileDown className="size-5" aria-hidden="true" />}
            title="You supply Lecram's DLL"
            detail="Drop nvngx_dlssnr.dll into ~/.local/share/ascension/import or Downloads. Ascension does not download it."
          />
        </ol>

        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <a
            href="/api/ascension"
            download="ascension"
            className="inline-flex h-12 cursor-pointer items-center justify-center bg-gold px-5 text-sm font-semibold text-gold-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold"
          >
            Download Ascension
          </a>
          <button
            type="button"
            onClick={onDryRun}
            disabled={phase === "run"}
            className="inline-flex h-12 items-center justify-center border border-line bg-raise px-5 text-sm font-medium text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold disabled:opacity-60"
          >
            {phase === "run" ? "Running dry-run…" : "Dry-run the plan"}
          </button>
        </div>
        <p className="mt-3 text-sm leading-relaxed text-muted">
          On the Linux PC where AION 2 is installed, run{" "}
          <span className="text-ink">bash ascension</span>. No window. Quit Steam
          fully once so the launch option sticks, then start the game from Steam.
          Needs Proton-GE, Proton-CachyOS, Wine-GE, or system Wine — not official
          Proton.
        </p>

        <aside className="mt-8 border border-line bg-raise p-4">
          <p className="text-xs font-semibold tracking-widest text-clay uppercase">
            Not an anti-cheat bypass
          </p>
          <p className="mt-2 text-sm leading-relaxed text-ink">
            Ascension does not disable NC Guard, hide from it, or patch it. It
            only keeps the mod out of the game folder. The Vulkan layer still
            loads in the game process. Undo with{" "}
            <span className="text-gold">ascension --remove</span>.
          </p>
        </aside>

        <section className="mt-6 border border-line bg-raise" aria-live="polite">
          <p className="border-b border-line px-4 py-2 text-xs tracking-widest text-muted uppercase">
            {phase === "done" ? "Dry-run on an empty demo account" : "What the command does"}
          </p>
          <pre className="max-h-80 overflow-auto px-4 py-4 text-sm leading-relaxed break-all whitespace-pre-wrap text-ink">
            {log}
          </pre>
        </section>
      </div>
    </main>
  );
}

function Step({
  n,
  icon,
  title,
  detail,
}: {
  n: string;
  icon: ReactNode;
  title: string;
  detail: string;
}) {
  return (
    <li className="flex gap-4 border-b border-line py-4 last:border-b-0">
      <span className="w-8 shrink-0 font-display text-lg text-gold">{n}</span>
      <div className="min-w-0">
        <p className="flex items-center gap-2 text-base font-medium text-ink">
          <span className="text-gold">{icon}</span>
          {title}
        </p>
        <p className="mt-1 text-sm leading-relaxed text-muted">{detail}</p>
      </div>
    </li>
  );
}
