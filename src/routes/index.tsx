import { createFileRoute } from "@tanstack/react-router";
import { type ReactNode } from "react";
import { FileDown, FolderX, Play } from "lucide-react";

export const Route = createFileRoute("/")({ component: Home });

const PLAN = `ascension
turns the DLSS 5 layer on for Steam games you tick
writes nothing inside a game folder

  1. DLSS5VKLayer under ~/.local
  2. nvngx_dlssnr.dll into the helper, not the game
  3. each ticked game gets VKLayer_DLSS5=1 %command%`;

function Home() {
  return (
    <main className="min-h-dvh bg-bg text-ink">
      <div className="mx-auto flex w-full max-w-2xl flex-col px-5 py-10 sm:px-8 sm:py-14">
        <p className="text-xs font-medium tracking-widest text-gold uppercase">
          Linux · Steam
        </p>
        <h1 className="mt-3 font-display text-5xl leading-none text-ink sm:text-6xl">
          Ascension
        </h1>
        <p className="mt-4 max-w-prose text-base leading-relaxed text-muted">
          Get Lecram's DLL, download the AppImage, then tick the Steam games
          you want. The Vulkan layer stays in your home directory. Game folders
          are not touched.
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
            icon={<FileDown className="size-5" aria-hidden="true" />}
            title="Download Lecram's DLL"
            detail={
              <>
                Get{" "}
                <span className="text-ink">nvngx_dlssnr.dll</span> from the{" "}
                <a
                  href="https://github.com/RankFTW/rhi-repo/releases/download/dlssnr-310.8.Lecram/nvngx_dlssnr_310.8.Lecram.zip"
                  className="text-gold underline decoration-gold/40 underline-offset-2"
                >
                  DLSSNR
                </a>
                , put the nvngx_dlssnr.dll in{" "}
                <span className="text-ink">Downloads</span>{" "}
              </>
            }
          />
          <Step
            n="03"
            icon={<Play className="size-5" aria-hidden="true" />}
            title="Launch the app"
            detail="Double-click the AppImage and tick the Steam games you want. Ticked ones get a launch option only. Unticked ones are left alone."
          />
        </ol>

        <div className="mt-8">
          <a
            href="/Ascension-x86_64.AppImage"
            download="Ascension-x86_64.AppImage"
            className="inline-flex h-12 cursor-pointer items-center justify-center bg-gold px-5 text-sm font-semibold text-gold-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gold"
          >
            Download Ascension
          </a>
        </div>
        <p className="mt-3 text-sm leading-relaxed text-muted">
          On your Linux PC, double-click{" "}
          <span className="text-ink">Ascension-x86_64.AppImage</span>. If the
          file browser will not run it, mark it executable once. Tick the games,
          quit Steam fully once so the launch options stick, then start them
          from Steam. The helper needs Proton-GE, Proton-CachyOS, Wine-GE, or
          system Wine. Live tweaks are in{" "}
          <span className="text-ink">dlssnr-gui</span>, a separate window.
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

        <section className="mt-6 border border-line bg-raise">
          <p className="border-b border-line px-4 py-2 text-xs tracking-widest text-muted uppercase">
            What the command does
          </p>
          <pre className="max-h-80 overflow-auto px-4 py-4 text-sm leading-relaxed break-all whitespace-pre-wrap text-ink">
            {PLAN}
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
  detail: ReactNode;
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
