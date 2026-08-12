"use client";

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from "react";
import {
  AudioLines,
  ChevronDown,
  ChevronUp,
  ClipboardList,
  CirclePlus,
  ListChecks,
  Check,
  Minus,
  Pause,
  Pin,
  Play,
  Plus,
  RotateCcw,
  Settings,
  SkipBack,
  SkipForward,
  Timer,
  Trash2,
} from "lucide-react";
import { motion } from "framer-motion";
import Image from "next/image";
import { useLocale } from "@/context/locale-context";
import { asset } from "@/lib/asset";
import { MacNotchFrame } from "./mac-notch-frame";
import { VoiceBars } from "./voice-bars";
import { cn } from "@/lib/utils";

export type IslandTab = "media" | "clipboard" | "tasks" | "timer" | "counter";

const tabs: IslandTab[] = ["media", "clipboard", "tasks", "timer", "counter"];

const tabIcons: Record<IslandTab, typeof AudioLines> = {
  media: AudioLines,
  clipboard: ClipboardList,
  tasks: ListChecks,
  timer: Timer,
  counter: CirclePlus,
};

const dockableTabs: IslandTab[] = ["clipboard", "tasks", "timer", "counter"];

const EXPANDED_W = 660;
const EXPANDED_H = 248;
const COMPACT_H = 40;
/** Ada inset 2.5 — kapak yüksekliği ada ile eşmerkezli eğri için tam oturur. */
const ART_INSET = 2.5;
const ART_COMPACT = COMPACT_H - ART_INSET * 2;
/** Telefon: layout değişmez; tüm demo bu genişliğe scale edilir. */
const DESIGN_W = 720;

const CLIP_IDS = [
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "10",
  "11",
  "12",
] as const;

type ClipItem = { id: string; text: string };

type TaskItem = {
  id: string;
  title: string;
  completed: boolean;
};

function formatTimer(ms: number) {
  const cs = Math.floor(ms / 10);
  const m = Math.floor(cs / 6000);
  const s = Math.floor((cs % 6000) / 100);
  const c = cs % 100;
  if (m >= 60) {
    const h = Math.floor(m / 60);
    const mm = m % 60;
    return `${h}:${String(mm).padStart(2, "0")}:${String(s).padStart(2, "0")}.${String(c).padStart(2, "0")}`;
  }
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}.${String(c).padStart(2, "0")}`;
}

function formatClock(seconds: number) {
  const total = Math.floor(seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) {
    return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }
  return `${m}:${String(s).padStart(2, "0")}`;
}

export function DynamicIslandDemo({
  tab: controlledTab,
  onTabChange,
}: {
  tab?: IslandTab;
  onTabChange?: (tab: IslandTab) => void;
} = {}) {
  const { t } = useLocale();
  const [expanded, setExpanded] = useState(true);
  const [internalTab, setInternalTab] = useState<IslandTab>("media");
  const tab = controlledTab ?? internalTab;
  const setTab = (next: IslandTab) => {
    if (controlledTab === undefined) setInternalTab(next);
    onTabChange?.(next);
  };
  const [pinned, setPinned] = useState(false);
  const [isDocked, setIsDocked] = useState(false);

  const [playing, setPlaying] = useState(true);
  const [elapsed, setElapsed] = useState(94);
  /** Bengü — İki Melek · 4:10 */
  const duration = 250;

  const [timerRunning, setTimerRunning] = useState(true);
  const [timerMs, setTimerMs] = useState(452_340);

  const [count, setCount] = useState(12);
  const [counterNote, setCounterNote] = useState("");

  const [tasks, setTasks] = useState<TaskItem[]>(() =>
    t.tasks.samples.map((title, i) => ({
      id: `t${i + 1}`,
      title,
      completed: i === 2,
    })),
  );
  const [selectedTaskId, setSelectedTaskId] = useState("t1");
  const [taskDraft, setTaskDraft] = useState("");
  const [taskFilter, setTaskFilter] = useState<"all" | "active" | "completed">(
    "all",
  );

  const clipSamples = useMemo(() => {
    const map: Record<string, string> = {};
    t.clipboard.samples.forEach((text, i) => {
      map[String(i + 1)] = text;
    });
    return map;
  }, [t]);
  const [hiddenClipIds, setHiddenClipIds] = useState<Set<string>>(new Set());
  const clipItems: ClipItem[] = CLIP_IDS.filter((id) => !hiddenClipIds.has(id)).map(
    (id) => ({ id, text: clipSamples[id] }),
  );
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const [dragX, setDragX] = useState(0);
  const [pageWidth, setPageWidth] = useState(EXPANDED_W - 36);
  const [shellWidth, setShellWidth] = useState(DESIGN_W);
  const [designHeight, setDesignHeight] = useState(400);
  const [canHover, setCanHover] = useState(true);
  const pageRef = useRef<HTMLDivElement>(null);
  const shellRef = useRef<HTMLDivElement>(null);
  const designRef = useRef<HTMLDivElement>(null);
  const dragging = useRef(false);
  const startX = useRef(0);
  const pointerInside = useRef(false);
  const expandTimer = useRef<number | null>(null);
  const collapseTimer = useRef<number | null>(null);
  const pinnedRef = useRef(pinned);
  const dockedRef = useRef(isDocked);
  const expandedRef = useRef(expanded);
  const canHoverRef = useRef(canHover);

  useEffect(() => {
    pinnedRef.current = pinned;
    dockedRef.current = isDocked;
    expandedRef.current = expanded;
    canHoverRef.current = canHover;
  }, [pinned, isDocked, expanded, canHover]);

  useEffect(() => {
    const mq = window.matchMedia("(hover: hover) and (pointer: fine)");
    const sync = () => setCanHover(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);

  useEffect(() => {
    const el = shellRef.current;
    if (!el) return;
    const measure = () => {
      const w = el.clientWidth;
      if (w > 0) setShellWidth(w);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const el = designRef.current;
    if (!el) return;
    const measure = () => {
      const h = el.offsetHeight;
      if (h > 0) setDesignHeight(h);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const clearHoverTimers = useCallback(() => {
    if (expandTimer.current !== null) {
      window.clearTimeout(expandTimer.current);
      expandTimer.current = null;
    }
    if (collapseTimer.current !== null) {
      window.clearTimeout(collapseTimer.current);
      collapseTimer.current = null;
    }
  }, []);

  useEffect(() => () => clearHoverTimers(), [clearHoverTimers]);

  /** Desktop: hover expand/collapse. Touch: tap only (hover yok). */
  const onIslandPointerEnter = () => {
    pointerInside.current = true;
    clearHoverTimers();
    if (!canHoverRef.current) return;
    if (dockedRef.current) return;
    if (expandedRef.current) return;
    expandTimer.current = window.setTimeout(() => {
      if (!pointerInside.current || dockedRef.current) return;
      setExpanded(true);
    }, 80);
  };

  const onIslandPointerLeave = () => {
    pointerInside.current = false;
    clearHoverTimers();
    if (!canHoverRef.current) return;
    if (dockedRef.current) return;
    if (!expandedRef.current || pinnedRef.current) return;
    collapseTimer.current = window.setTimeout(() => {
      if (pointerInside.current || pinnedRef.current || dockedRef.current) return;
      setIsDocked(false);
      setExpanded(false);
    }, 120);
  };

  const onBackdropPointerDown = () => {
    if (canHoverRef.current) return;
    if (!expandedRef.current || pinnedRef.current || dockedRef.current) return;
    clearHoverTimers();
    setExpanded(false);
  };

  useEffect(() => {
    if (!playing) return;
    const id = window.setInterval(() => {
      setElapsed((v) => (v >= duration ? 0 : v + 1));
    }, 1000);
    return () => window.clearInterval(id);
  }, [playing, duration]);

  useEffect(() => {
    if (!timerRunning) return;
    const id = window.setInterval(() => setTimerMs((v) => v + 10), 10);
    return () => window.clearInterval(id);
  }, [timerRunning]);

  useEffect(() => {
    const el = pageRef.current;
    if (!el || !expanded) return;
    const measure = () => {
      const w = el.clientWidth;
      if (w > 0) setPageWidth(w);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [expanded]);

  const tabLabels: Record<IslandTab, string> = {
    media: t.islandTabs.media,
    clipboard: t.islandTabs.clipboard,
    tasks: t.islandTabs.tasks,
    timer: t.islandTabs.timer,
    counter: t.islandTabs.counter,
  };

  const tabIndex = tabs.indexOf(tab);

  const selectTab = useCallback(
    (next: IslandTab) => {
      setTab(next);
      setDragX(0);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps -- setTab closes over controlled props
    [controlledTab, onTabChange],
  );

  const shiftTab = useCallback(
    (delta: number) => {
      const idx = tabs.indexOf(tab);
      const next = idx + delta;
      if (next >= 0 && next < tabs.length) {
        setTab(tabs[next]);
        setDragX(0);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [tab, controlledTab, onTabChange],
  );

  const dockToIsland = () => {
    clearHoverTimers();
    pointerInside.current = false;
    setPinned(false);
    setIsDocked(true);
    setExpanded(false);
  };

  const expandFromDock = () => {
    clearHoverTimers();
    pointerInside.current = true;
    setIsDocked(false);
    setExpanded(true);
  };

  const toggleExpand = () => {
    if (isDocked) return;
    clearHoverTimers();
    if (!expanded) {
      pointerInside.current = true;
      setExpanded(true);
    }
  };

  const togglePin = () => {
    setPinned((wasPinned) => {
      const willPin = !wasPinned;
      if (willPin) {
        clearHoverTimers();
        setIsDocked(false);
        setExpanded(true);
      } else if (!pointerInside.current) {
        setExpanded(false);
      }
      return willPin;
    });
  };

  const onPagePointerDown = (e: ReactPointerEvent) => {
    if (!expanded) return;
    const target = e.target as HTMLElement;
    if (target.closest("button, input, textarea, a, [data-no-swipe]")) return;
    dragging.current = true;
    startX.current = e.clientX;
    pageRef.current?.setPointerCapture(e.pointerId);
  };

  const onPagePointerMove = (e: ReactPointerEvent) => {
    if (!dragging.current) return;
    const dx = e.clientX - startX.current;
    const isFirst = tabIndex === 0;
    const isLast = tabIndex === tabs.length - 1;
    let clamped = dx;
    if ((isFirst && dx > 0) || (isLast && dx < 0)) clamped = dx * 0.3;
    setDragX(clamped);
  };

  const onPagePointerUp = (e: ReactPointerEvent) => {
    if (!dragging.current) return;
    dragging.current = false;
    const width = pageWidth;
    const threshold = Math.max(width * (canHoverRef.current ? 0.1 : 0.08), canHoverRef.current ? 22 : 16);
    if (dragX <= -threshold) shiftTab(1);
    else if (dragX >= threshold) shiftTab(-1);
    setDragX(0);
    pageRef.current?.releasePointerCapture(e.pointerId);
  };

  const copyItem = (item: ClipItem) => {
    setCopiedId(item.id);
    window.setTimeout(() => setCopiedId(null), 1200);
  };

  const clearClipboard = () => setHiddenClipIds(new Set(CLIP_IDS));

  const filteredTasks = useMemo(() => {
    if (taskFilter === "active") return tasks.filter((t) => !t.completed);
    if (taskFilter === "completed") return tasks.filter((t) => t.completed);
    return tasks;
  }, [tasks, taskFilter]);

  const selectedTask = tasks.find((t) => t.id === selectedTaskId);
  const islandTaskLabel = selectedTask
    ? selectedTask.title.trim().slice(0, 8) || "—"
    : "—";

  const addTask = () => {
    const title = taskDraft.trim();
    if (!title) return;
    const id = `t${Date.now()}`;
    setTasks((prev) => [{ id, title, completed: false }, ...prev]);
    setSelectedTaskId(id);
    setTaskDraft("");
  };

  const toggleTask = (id: string) => {
    setTasks((prev) =>
      prev.map((item) =>
        item.id === id ? { ...item, completed: !item.completed } : item,
      ),
    );
  };

  const completeSelectedTask = () => {
    if (!selectedTask || selectedTask.completed) return;
    setTasks((prev) =>
      prev.map((item) =>
        item.id === selectedTaskId ? { ...item, completed: true } : item,
      ),
    );
    const next = tasks.find(
      (item) => item.id !== selectedTaskId && !item.completed,
    );
    if (next) setSelectedTaskId(next.id);
  };

  const deleteTask = (id: string) => {
    setTasks((prev) => prev.filter((item) => item.id !== id));
    if (selectedTaskId === id) {
      const remaining = tasks.filter((item) => item.id !== id);
      setSelectedTaskId(
        remaining.find((item) => !item.completed)?.id ?? remaining[0]?.id ?? "",
      );
    }
  };

  // Sadece dar telefon: sabit tasarım genişliğine scale. Tablet/masaüstü: tam genişlik.
  const usePhoneScale = shellWidth > 0 && shellWidth < 640;
  const scale = usePhoneScale ? Math.min(1, shellWidth / DESIGN_W) : 1;
  const compactWidth =
    tab === "media"
      ? 360
      : tab === "clipboard"
        ? 220
        : tab === "tasks"
          ? 280
          : 270;
  const showVoiceBars =
    !isDocked && (tab === "media" || tab === "clipboard" || tab === "tasks");
  const canDock = dockableTabs.includes(tab);
  const targetW = expanded ? EXPANDED_W : compactWidth;
  const targetH = expanded ? EXPANDED_H : COMPACT_H;
  const dragPct = pageWidth > 0 ? (dragX / pageWidth) * 100 : 0;

  const sizeTransition = expanded
    ? { duration: 0.52, ease: [0.32, 0.72, 0, 1] as const }
    : { type: "spring" as const, stiffness: 420, damping: 34, mass: 0.85 };

  return (
    <div
      ref={shellRef}
      className="w-full touch-manipulation"
      style={usePhoneScale ? { height: designHeight * scale } : undefined}
    >
      <div
        ref={designRef}
        className={usePhoneScale ? "mx-auto origin-top" : "w-full"}
        style={
          usePhoneScale
            ? { width: DESIGN_W, transform: `scale(${scale})` }
            : undefined
        }
      >
        <MacNotchFrame onBackdropPointerDown={onBackdropPointerDown}>
          <motion.div
            className="relative"
            initial={false}
            animate={{ width: targetW, height: targetH }}
            transition={sizeTransition}
            onPointerEnter={onIslandPointerEnter}
            onPointerLeave={onIslandPointerLeave}
            onPointerDown={(e) => e.stopPropagation()}
          >
            <div className="absolute -inset-2 z-0" aria-hidden />

            <motion.div
              className="apple-island-surface absolute left-1/2 top-0 z-10 -translate-x-1/2 overflow-hidden text-white"
              initial={false}
              animate={{
                width: targetW,
                height: targetH,
                borderTopLeftRadius: 0,
                borderTopRightRadius: 0,
                borderBottomLeftRadius: expanded ? 22 : COMPACT_H / 2,
                borderBottomRightRadius: expanded ? 22 : COMPACT_H / 2,
              }}
              transition={sizeTransition}
              style={{
                borderTopLeftRadius: 0,
                borderTopRightRadius: 0,
              }}
            >
          {/* Compact — üstte sabit; panel küçülünce görünür */}
          <motion.div
            className={cn(
              "absolute inset-x-0 top-0 flex h-[40px] items-center",
              expanded ? "pointer-events-none" : "pointer-events-auto",
            )}
            initial={false}
            animate={{
              opacity: expanded ? 0 : 1,
              y: expanded ? -4 : 0,
            }}
            transition={{
              duration: expanded ? 0.18 : 0.28,
              delay: expanded ? 0 : 0.12,
              ease: [0.32, 0.72, 0, 1],
            }}
          >
            <div
              className={cn(
                "flex h-full flex-1 items-center",
                tab === "media" ? "pr-2.5" : "pl-2.5",
              )}
            >
              <button
                type="button"
                onClick={toggleExpand}
                className="flex min-w-0 flex-1 items-center justify-between text-left"
                aria-label={t.controls.expand}
              >
                <CompactLead
                  tab={tab}
                  timerLabel={formatTimer(timerMs)}
                  count={count}
                  clipCount={clipItems.length}
                  taskLabel={islandTaskLabel}
                />
                {showVoiceBars && (
                  <VoiceBars
                    playing={
                      tab === "media" ? playing : true
                    }
                    className="mr-2.5"
                  />
                )}
              </button>

              <div className="mr-1.5 flex shrink-0 items-center gap-1.5">
                {tab === "timer" && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setTimerRunning((v) => !v);
                    }}
                    className="flex size-[22px] items-center justify-center rounded-full bg-white text-black"
                    aria-label={timerRunning ? t.timer.stop : t.timer.start}
                  >
                    {timerRunning ? (
                      <Pause className="size-2.5 fill-current" />
                    ) : (
                      <Play className="size-2.5 fill-current pl-0.5" />
                    )}
                  </button>
                )}

                {tab === "counter" && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setCount((v) => v + 1);
                    }}
                    className="flex size-[22px] items-center justify-center rounded-full bg-[#2b2b2e] text-white ring-1 ring-white/15"
                    aria-label={t.counter.increase}
                  >
                    <Plus className="size-2.5" />
                  </button>
                )}

                {tab === "tasks" && isDocked && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      completeSelectedTask();
                    }}
                    disabled={!selectedTask || selectedTask.completed}
                    className="flex size-[22px] items-center justify-center rounded-full bg-[#2b2b2e] text-white ring-1 ring-white/15 disabled:opacity-35"
                    aria-label={t.tasks.completeSelected}
                  >
                    <Check className="size-2.5" />
                  </button>
                )}

                {isDocked && (
                  <button
                    type="button"
                    className="flex size-[22px] items-center justify-center rounded-full bg-[#2b2b2e] text-white/70 ring-1 ring-white/15"
                    onClick={expandFromDock}
                    aria-label={t.controls.expand}
                  >
                    <ChevronDown className="size-2.5" />
                  </button>
                )}
              </div>
            </div>
          </motion.div>

          {/* Expanded — her zaman tam boyutta çizilir; clip parent ile kesilir */}
          <motion.div
            className={cn(
              "absolute left-1/2 top-0 flex -translate-x-1/2 flex-col",
              expanded ? "pointer-events-auto" : "pointer-events-none",
            )}
            style={{ width: EXPANDED_W, height: EXPANDED_H }}
            initial={false}
            animate={{
              opacity: expanded ? 1 : 0,
              y: expanded ? 0 : 8,
            }}
            transition={{
              duration: expanded ? 0.28 : 0.2,
              delay: expanded ? 0.08 : 0,
              ease: [0.32, 0.72, 0, 1],
            }}
          >
            <div className="px-3.5 pb-2.5 pt-2">
              <div className="flex items-center gap-2">
                <IslandTabBar
                  tab={tab}
                  labels={tabLabels}
                  dragFraction={-dragPct / 100}
                  onSelect={selectTab}
                />
                <div className="ml-auto flex items-center">
                  {tab === "clipboard" && (
                    <>
                      <span className="px-1 text-[11px] font-bold tabular-nums text-white/55">
                        {clipItems.length}
                      </span>
                      <IconBtn
                        label={t.clipboard.clear}
                        disabled={clipItems.length === 0}
                        onClick={clearClipboard}
                        className={clipItems.length === 0 ? "opacity-20" : ""}
                      >
                        <Trash2 className="size-3" />
                      </IconBtn>
                    </>
                  )}
                  {pinned && (
                    <span className="px-1 text-[9px] font-bold uppercase tracking-wider text-dyno-accent">
                      {t.controls.pinned}
                    </span>
                  )}
                  {(canDock) && (
                    <IconBtn
                      label={t.controls.collapseToIsland}
                      onClick={dockToIsland}
                    >
                      <ChevronUp className="size-3" />
                    </IconBtn>
                  )}
                  <IconBtn
                    label={pinned ? t.controls.unpin : t.controls.pin}
                    active={pinned}
                    onClick={togglePin}
                  >
                    <Pin
                      className={cn(
                        "size-3",
                        pinned && "fill-dyno-accent text-dyno-accent",
                      )}
                    />
                  </IconBtn>
                  <IconBtn label={t.controls.settings}>
                    <Settings className="size-3" />
                  </IconBtn>
                </div>
              </div>
            </div>

            <div className="mx-[18px] h-px bg-white/8" />

            <div className="min-h-0 flex-1 overflow-hidden px-[18px] pt-3 pb-0">
              <div
                ref={pageRef}
                className="relative h-full w-full touch-pan-y overflow-hidden"
                onPointerDown={onPagePointerDown}
                onPointerMove={onPagePointerMove}
                onPointerUp={onPagePointerUp}
                onPointerCancel={onPagePointerUp}
              >
                {tabs.map((id, i) => (
                  <motion.div
                    key={id}
                    className="absolute inset-0 overflow-hidden"
                    initial={false}
                    animate={{
                      x: `${(i - tabIndex) * 100 + dragPct}%`,
                    }}
                    transition={
                      dragX !== 0
                        ? { duration: 0 }
                        : { type: "spring", stiffness: 420, damping: 38 }
                    }
                  >
                    {id === "media" && (
                      <MediaPage
                        playing={playing}
                        elapsed={elapsed}
                        duration={duration}
                        onToggle={() => setPlaying((v) => !v)}
                        onSkip={(d) =>
                          setElapsed((v) =>
                            Math.max(0, Math.min(duration, v + d)),
                          )
                        }
                        onScrub={(v) => setElapsed(v)}
                      />
                    )}
                    {id === "clipboard" && (
                      <ClipboardPage
                        items={clipItems}
                        copiedId={copiedId}
                        onCopy={copyItem}
                      />
                    )}
                    {id === "tasks" && (
                      <TasksPage
                        tasks={filteredTasks}
                        selectedId={selectedTaskId}
                        draft={taskDraft}
                        filter={taskFilter}
                        onDraftChange={setTaskDraft}
                        onFilterChange={setTaskFilter}
                        onAdd={addTask}
                        onSelect={setSelectedTaskId}
                        onToggle={toggleTask}
                        onDelete={deleteTask}
                      />
                    )}
                    {id === "timer" && (
                      <TimerPage
                        label={formatTimer(timerMs)}
                        running={timerRunning}
                        onToggle={() => setTimerRunning((v) => !v)}
                        onReset={() => {
                          setTimerMs(0);
                          setTimerRunning(false);
                        }}
                      />
                    )}
                    {id === "counter" && (
                      <CounterPage
                        count={count}
                        note={counterNote}
                        onNoteChange={setCounterNote}
                        onIncrement={() => setCount((v) => v + 1)}
                        onDecrement={() =>
                          setCount((v) => Math.max(0, v - 1))
                        }
                        onReset={() => setCount(0)}
                      />
                    )}
                  </motion.div>
                ))}
              </div>
            </div>
          </motion.div>
        </motion.div>
      </motion.div>
        </MacNotchFrame>
      </div>
    </div>
  );
}

function CompactLead({
  tab,
  timerLabel,
  count,
  clipCount,
  taskLabel,
}: {
  tab: IslandTab;
  timerLabel: string;
  count: number;
  clipCount: number;
  taskLabel: string;
}) {
  if (tab === "media") {
    // Ada: üst 0, alt COMPACT_H/2. Kapak inset 2.5 ile eşmerkezli iç eğri.
    const bottomLead = COMPACT_H / 2 - ART_INSET;
    const topLead = 0;
    const trail = 7;
    const radius = `${trail}px ${trail}px ${trail}px ${bottomLead}px`;
    return (
      <div
        className="relative shrink-0 overflow-hidden"
        style={{
          width: ART_COMPACT,
          height: ART_COMPACT,
          marginLeft: ART_INSET,
          borderRadius: radius,
        }}
      >
        <Image
          src={asset("/album-art.jpg")}
          alt=""
          fill
          sizes="35px"
          className="object-cover"
          style={{ borderRadius: radius }}
        />
      </div>
    );
  }

  if (tab === "timer") {
    return (
      <span className="pl-2 font-mono text-xs font-semibold tabular-nums">
        {timerLabel}
      </span>
    );
  }

  if (tab === "counter") {
    return (
      <span className="pl-2 text-sm font-bold tabular-nums">{count}</span>
    );
  }

  if (tab === "tasks") {
    return (
      <span
        className="max-w-[72px] truncate pl-2 text-xs font-semibold"
        style={{
          maskImage:
            "linear-gradient(90deg, #000 0%, #000 55%, transparent 100%)",
          WebkitMaskImage:
            "linear-gradient(90deg, #000 0%, #000 55%, transparent 100%)",
        }}
      >
        {taskLabel}
      </span>
    );
  }

  return (
    <span className="pl-2 text-sm font-bold tabular-nums">{clipCount}</span>
  );
}

function IslandTabBar({
  tab,
  labels,
  dragFraction,
  onSelect,
  iconsOnly = false,
}: {
  tab: IslandTab;
  labels: Record<IslandTab, string>;
  dragFraction: number;
  onSelect: (tab: IslandTab) => void;
  iconsOnly?: boolean;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [frames, setFrames] = useState<Record<number, DOMRect>>({});

  const measure = useCallback(() => {
    const el = containerRef.current;
    if (!el) return;
    const bar = el.getBoundingClientRect();
    const next: Record<number, DOMRect> = {};
    el.querySelectorAll<HTMLElement>("[data-tab-idx]").forEach((node) => {
      const idx = Number(node.dataset.tabIdx);
      const r = node.getBoundingClientRect();
      next[idx] = new DOMRect(
        r.left - bar.left,
        r.top - bar.top,
        r.width,
        r.height,
      );
    });
    setFrames(next);
  }, []);

  useEffect(() => {
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [measure, labels, iconsOnly]);

  const idx = tabs.indexOf(tab);
  const raw = idx - dragFraction;
  const clamped = Math.min(Math.max(raw, 0), tabs.length - 1);
  const lower = Math.floor(clamped);
  const upper = Math.min(lower + 1, tabs.length - 1);
  const fraction = clamped - lower;
  const a = frames[lower];
  const b = frames[upper];
  const indicator =
    a && b
      ? {
          x: a.left + (b.left - a.left) * fraction,
          y: a.top + (b.top - a.top) * fraction,
          w: a.width + (b.width - a.width) * fraction,
          h: a.height + (b.height - a.height) * fraction,
        }
      : null;

  return (
    <div ref={containerRef} className="relative flex min-w-0 gap-0.5 sm:gap-1">
      {indicator && indicator.w > 1 && (
        <motion.span
          className="absolute rounded-full bg-white/10 ring-1 ring-white/15 backdrop-blur-sm"
          animate={{
            left: indicator.x,
            top: indicator.y,
            width: indicator.w,
            height: indicator.h,
          }}
          transition={{ type: "spring", stiffness: 420, damping: 32 }}
        />
      )}
      {tabs.map((id, i) => {
        const Icon = tabIcons[id];
        const active = tab === id;
        return (
          <button
            key={id}
            type="button"
            data-tab-idx={i}
            onClick={() => onSelect(id)}
            aria-label={labels[id]}
            className={cn(
              "relative z-10 flex h-8 min-w-8 items-center justify-center gap-1 rounded-full px-2 text-[10px] font-semibold transition-colors sm:h-7 sm:px-2.5 sm:text-[10.5px]",
              active
                ? "text-white"
                : "text-white/42 active:text-white/70 sm:hover:text-white/70",
            )}
          >
            <Icon className="size-3 shrink-0 sm:size-2.5" />
            {!iconsOnly && <span className="truncate">{labels[id]}</span>}
          </button>
        );
      })}
    </div>
  );
}

function IconBtn({
  children,
  label,
  active,
  disabled,
  onClick,
  className,
}: {
  children: React.ReactNode;
  label: string;
  active?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  className?: string;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "flex size-9 items-center justify-center rounded-md text-white/55 transition active:bg-white/10 sm:size-7 sm:hover:bg-white/8 sm:hover:text-white/90 disabled:pointer-events-none",
        active && "text-dyno-accent",
        className,
      )}
    >
      {children}
    </button>
  );
}

function MediaPage({
  playing,
  elapsed,
  duration,
  onToggle,
  onSkip,
  onScrub,
}: {
  playing: boolean;
  elapsed: number;
  duration: number;
  onToggle: () => void;
  onSkip: (delta: number) => void;
  onScrub: (value: number) => void;
}) {
  const { t } = useLocale();
  const progress = duration > 0 ? (elapsed / duration) * 100 : 0;

  return (
    <div className="box-border flex h-full w-full min-w-0 flex-col justify-between gap-2 overflow-hidden pb-1 sm:gap-2.5">
      <div className="flex min-w-0 gap-2.5 sm:gap-3.5">
        <div
          className="relative h-[72px] w-[128px] shrink-0 overflow-hidden ring-1 ring-white/10 sm:h-[100px] sm:w-[178px]"
          style={{ borderRadius: 12 }}
        >
          <Image
            src={asset("/album-art.jpg")}
            alt=""
            fill
            sizes="(max-width: 640px) 128px, 178px"
            className="object-cover"
            priority
          />
        </div>
        <div className="flex min-w-0 flex-1 flex-col">
          <p className="truncate text-[10px] font-medium text-white/45 sm:text-[11px]">
            {t.media.app}
          </p>
          <p className="mt-1 line-clamp-2 text-[14px] font-semibold leading-tight tracking-tight sm:mt-1.5 sm:text-[16px]">
            {t.media.title}
          </p>
          <p className="mt-0.5 truncate text-[11px] font-medium text-white/50 sm:text-[12.5px]">
            {t.media.artist}
          </p>
          <div className="mt-auto flex items-center gap-2.5 pt-1.5 sm:gap-3.5 sm:pt-2">
            <RoundBtn aria-label={t.media.previous}>
              <SkipBack className="size-3 fill-current" />
            </RoundBtn>
            <button
              type="button"
              onClick={onToggle}
              className="flex size-9 shrink-0 items-center justify-center rounded-full bg-white text-black sm:size-[34px]"
              aria-label={playing ? t.media.pause : t.media.play}
            >
              {playing ? (
                <Pause className="size-3.5 fill-current" />
              ) : (
                <Play className="size-3.5 fill-current pl-0.5" />
              )}
            </button>
            <RoundBtn aria-label={t.media.next}>
              <SkipForward className="size-3 fill-current" />
            </RoundBtn>
          </div>
        </div>
      </div>

      <div className="w-full min-w-0 space-y-2">
        <input
          type="range"
          min={0}
          max={duration}
          step={1}
          value={elapsed}
          data-no-swipe
          onChange={(e) => onScrub(Number(e.target.value))}
          className="h-1 w-full min-w-0 cursor-pointer appearance-none rounded-full bg-white/10 accent-dyno-accent [&::-webkit-slider-thumb]:size-3 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-dyno-accent"
          style={{
            background: `linear-gradient(to right, var(--dyno-accent) ${progress}%, rgba(255,255,255,0.1) ${progress}%)`,
          }}
        />
        {/* App parity: elapsed | −10 | +10 | spacer | duration */}
        <div className="flex w-full min-w-0 items-center gap-2.5 font-mono text-[10px] font-medium text-white/40">
          <span className="min-w-10 shrink-0 tabular-nums">
            {formatClock(elapsed)}
          </span>
          <Chip onClick={() => onSkip(-10)}>{t.media.skipBack}</Chip>
          <Chip onClick={() => onSkip(10)}>{t.media.skipForward}</Chip>
          <span className="min-w-0 flex-1" />
          <span className="min-w-10 shrink-0 text-right tabular-nums">
            {formatClock(duration)}
          </span>
        </div>
      </div>
    </div>
  );
}

function TasksPage({
  tasks,
  selectedId,
  draft,
  filter,
  onDraftChange,
  onFilterChange,
  onAdd,
  onSelect,
  onToggle,
  onDelete,
}: {
  tasks: TaskItem[];
  selectedId: string;
  draft: string;
  filter: "all" | "active" | "completed";
  onDraftChange: (value: string) => void;
  onFilterChange: (value: "all" | "active" | "completed") => void;
  onAdd: () => void;
  onSelect: (id: string) => void;
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
}) {
  const { t } = useLocale();
  const filters: Array<"all" | "active" | "completed"> = [
    "all",
    "active",
    "completed",
  ];
  const filterLabel = {
    all: t.tasks.filterAll,
    active: t.tasks.filterActive,
    completed: t.tasks.filterCompleted,
  } as const;

  return (
    <div className="flex h-full flex-col gap-2.5 overflow-hidden" data-no-swipe>
      <div className="flex shrink-0 items-center gap-2">
        <input
          value={draft}
          onChange={(e) => onDraftChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") onAdd();
          }}
          placeholder={t.tasks.placeholder}
          className={cn(
            "h-[30px] min-w-0 flex-1 rounded-full border px-3 text-[12.5px] font-medium outline-none",
            "border-white/[0.08] bg-white/[0.06] text-white/92 placeholder:text-white/32",
            "focus:border-transparent focus:bg-white focus:text-black focus:placeholder:text-black/35",
          )}
        />
        <button
          type="button"
          onClick={onAdd}
          disabled={!draft.trim()}
          aria-label={t.tasks.add}
          className="flex size-[30px] shrink-0 items-center justify-center rounded-full bg-[#2b2b2e] text-white ring-1 ring-white/15 disabled:opacity-35"
        >
          <Plus className="size-3" />
        </button>
        <div className="flex shrink-0 items-center rounded-full bg-white/[0.05] p-0.5">
          {filters.map((key) => (
            <button
              key={key}
              type="button"
              onClick={() => onFilterChange(key)}
              className={cn(
                "h-[26px] rounded-full px-2 text-[10px] font-semibold",
                filter === key
                  ? "bg-white/12 text-white"
                  : "text-white/42",
              )}
            >
              {filterLabel[key]}
            </button>
          ))}
        </div>
      </div>

      {tasks.length === 0 ? (
        <div className="flex min-h-0 flex-1 flex-col items-center justify-center gap-2 py-4 text-center">
          <ListChecks className="size-6 text-white/32" />
          <p className="text-[13px] font-semibold text-white/80">
            {t.tasks.empty}
          </p>
          <p className="text-[11px] text-white/36">{t.tasks.emptyHint}</p>
        </div>
      ) : (
        <div className="min-h-0 flex-1 space-y-1.5 overflow-y-auto apple-scrollbar">
          {tasks.map((task) => {
            const selected = task.id === selectedId;
            return (
              <button
                key={task.id}
                type="button"
                onClick={() => onSelect(task.id)}
                className={cn(
                  "group flex w-full items-center gap-2.5 rounded-[12px] border px-2.5 py-2 text-left transition",
                  selected
                    ? "border-dyno-accent/70 bg-white/[0.12]"
                    : "border-white/[0.05] bg-white/[0.04] hover:border-white/14 hover:bg-white/[0.08]",
                )}
              >
                <span
                  role="checkbox"
                  aria-checked={task.completed}
                  tabIndex={0}
                  onClick={(e) => {
                    e.stopPropagation();
                    onToggle(task.id);
                  }}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      e.stopPropagation();
                      onToggle(task.id);
                    }
                  }}
                  className="flex size-[22px] shrink-0 items-center justify-center text-white/72"
                >
                  {task.completed ? (
                    <Check className="size-3.5 text-white/35" />
                  ) : (
                    <span className="size-3.5 rounded-full border border-white/55" />
                  )}
                </span>
                <span
                  className={cn(
                    "min-w-0 flex-1 truncate text-[12.5px] font-medium",
                    task.completed
                      ? "text-white/38 line-through"
                      : "text-white/92",
                  )}
                >
                  {task.title}
                </span>
                <span className="flex size-[22px] shrink-0 items-center justify-center">
                  <span
                    role="button"
                    tabIndex={0}
                    aria-label={t.tasks.delete}
                    onClick={(e) => {
                      e.stopPropagation();
                      onDelete(task.id);
                    }}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.preventDefault();
                        e.stopPropagation();
                        onDelete(task.id);
                      }
                    }}
                    className="flex size-[22px] items-center justify-center text-white/45 opacity-0 transition group-hover:opacity-100"
                  >
                    <Trash2 className="size-2.5" />
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

function ClipboardPage({
  items,
  copiedId,
  onCopy,
}: {
  items: ClipItem[];
  copiedId: string | null;
  onCopy: (item: ClipItem) => void;
}) {
  const { t } = useLocale();

  if (items.length === 0) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-2 py-6 text-center">
        <ClipboardList className="size-6 text-white/32" />
        <p className="text-[13px] font-semibold text-white/80">
          {t.clipboard.empty}
        </p>
        <p className="text-[11px] text-white/36">{t.clipboard.hint}</p>
      </div>
    );
  }

  return (
    <div className="h-full overflow-y-auto pr-0.5 apple-scrollbar">
      <div className="grid grid-cols-3 gap-2.5 pb-1">
        {items.map((item) => {
          const copied = copiedId === item.id;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onCopy(item)}
              className="relative min-h-[88px] rounded-[14px] border border-white/[0.06] bg-white/[0.045] p-2.5 text-left transition hover:border-white/14 hover:bg-white/[0.09]"
              data-no-swipe
            >
              <p
                className={cn(
                  "line-clamp-3 text-[11px] leading-snug text-white/85",
                  copied && "opacity-20",
                )}
              >
                {item.text}
              </p>
              {copied && (
                <span className="absolute inset-0 flex items-center justify-center text-[11px] font-bold text-white/90">
                  {t.clipboard.copied}
                </span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function TimerPage({
  label,
  running,
  onToggle,
  onReset,
}: {
  label: string;
  running: boolean;
  onToggle: () => void;
  onReset: () => void;
}) {
  const { t } = useLocale();

  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 py-1 sm:gap-4 sm:py-2">
      <p className="font-mono text-[28px] font-semibold tabular-nums leading-none tracking-tight sm:text-[42px]">
        {label}
      </p>
      <div className="flex items-center gap-4 sm:gap-[22px]">
        <button
          type="button"
          aria-label={t.timer.reset}
          onClick={onReset}
          className="flex size-11 items-center justify-center rounded-full bg-white/8 text-white/55 sm:size-10"
        >
          <RotateCcw className="size-3.5" />
        </button>
        <button
          type="button"
          onClick={onToggle}
          className="flex size-14 items-center justify-center rounded-full bg-white text-black"
          aria-label={running ? t.timer.stop : t.timer.start}
        >
          {running ? (
            <Pause className="size-[18px] fill-current" />
          ) : (
            <Play className="size-[18px] fill-current pl-0.5" />
          )}
        </button>
      </div>
    </div>
  );
}

function CounterPage({
  count,
  note,
  onNoteChange,
  onIncrement,
  onDecrement,
  onReset,
}: {
  count: number;
  note: string;
  onNoteChange: (v: string) => void;
  onIncrement: () => void;
  onDecrement: () => void;
  onReset: () => void;
}) {
  const { t } = useLocale();

  return (
    <div className="flex h-full min-h-0">
      <div className="relative min-w-0 flex-1 py-0.5 pr-2.5 sm:pr-3.5">
        {note.length === 0 && (
          <span className="pointer-events-none absolute left-1 top-2 text-[12px] text-white/28 sm:text-[13px]">
            {t.counter.notePlaceholder}
          </span>
        )}
        <textarea
          value={note}
          onChange={(e) => onNoteChange(e.target.value)}
          data-no-swipe
          className="h-full w-full resize-none bg-transparent text-[13px] text-white/92 outline-none"
          rows={5}
        />
      </div>
      <div className="my-1 w-px shrink-0 self-stretch bg-white/8" />
      <div className="flex min-w-0 flex-1 flex-col items-center justify-center gap-2.5 pl-2.5 sm:gap-3.5 sm:pl-3.5">
        <p className="text-[32px] font-bold tabular-nums leading-none sm:text-[40px]">
          {count}
        </p>
        <div className="flex items-center gap-2.5 sm:gap-3.5">
          <button
            type="button"
            aria-label={t.counter.decrease}
            disabled={count === 0}
            onClick={onDecrement}
            className="flex size-11 items-center justify-center rounded-full bg-white/8 text-white/70 disabled:opacity-35 sm:size-10"
          >
            <Minus className="size-3.5" />
          </button>
          <button
            type="button"
            onClick={onIncrement}
            className="flex size-14 items-center justify-center rounded-full bg-[#2b2b2e] ring-1 ring-white/15"
            aria-label={t.counter.increase}
          >
            <Plus className="size-5" />
          </button>
          <button
            type="button"
            aria-label={t.timer.reset}
            disabled={count === 0}
            onClick={onReset}
            className="flex size-11 items-center justify-center rounded-full bg-white/8 text-white/55 disabled:opacity-35 sm:size-10"
          >
            <RotateCcw className="size-3.5" />
          </button>
        </div>
      </div>
    </div>
  );
}

function Chip({
  children,
  onClick,
}: {
  children: React.ReactNode;
  onClick?: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="h-8 shrink-0 rounded-full bg-white/10 px-2.5 text-[10px] font-bold text-white/85 active:bg-white/16 sm:h-7 sm:px-2"
    >
      {children}
    </button>
  );
}

function RoundBtn({
  children,
  onClick,
  "aria-label": ariaLabel,
}: {
  children: React.ReactNode;
  onClick?: () => void;
  "aria-label"?: string;
}) {
  return (
    <button
      type="button"
      aria-label={ariaLabel}
      onClick={onClick}
      className="flex size-9 shrink-0 items-center justify-center text-white/75 active:text-white sm:size-7 sm:hover:text-white"
    >
      {children}
    </button>
  );
}
