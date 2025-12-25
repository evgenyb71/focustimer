const STORAGE_KEYS = {
  CONFIG: "config",
  STATE: "state"
};

const PHASES = {
  IDLE: "idle",
  RUNNING_A: "runningA",
  WAITING_A: "waitingForAConfirm",
  RUNNING_B: "runningB"
};

const ALARM_ID = "phaseEnd";
const HEARTBEAT_ALARM_ID = "heartbeat";

const DEFAULT_CONFIG = {
  durationASeconds: 60,
  durationBSeconds: 60
};

const DEFAULT_STATE = {
  phase: PHASES.IDLE,
  endTimestamp: null,
  paused: false,
  remainingSeconds: null
};

const NOTIFICATION_ICON = chrome.runtime.getURL("assets/icon128.png");
const BADGE_TEXT_VISIBLE = " "; // single space keeps badge visible without showing text
const BADGE_COLORS = {
  [PHASES.IDLE]: "#B0B0B0",
  [PHASES.RUNNING_A]: "#2a6f6b",
  [PHASES.WAITING_A]: "#d38400",
  [PHASES.RUNNING_B]: "#3b5998",
  paused: "#999999"
};

function nowMs() {
  return Date.now();
}

async function getStored(key, fallback) {
  const result = await chrome.storage.local.get(key);
  if (result[key] === undefined) {
    return fallback;
  }
  return result[key];
}

async function setStored(key, value) {
  await chrome.storage.local.set({ [key]: value });
}

async function getConfig() {
  return getStored(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
}

async function getState() {
  return getStored(STORAGE_KEYS.STATE, DEFAULT_STATE);
}

async function updateState(nextState) {
  await setStored(STORAGE_KEYS.STATE, nextState);
  await updateActionUI(nextState);
  chrome.runtime.sendMessage({ type: "stateChanged", state: nextState }, () => {
    // Ignore missing receivers.
    const err = chrome.runtime.lastError;
    if (err && !/Receiving end does not exist/.test(err.message || "")) {
      console.warn("stateChanged sendMessage failed", err);
    }
  });
}

function formatTitle(state) {
  if (state.phase === PHASES.IDLE) {
    return "Focus Timer: idle";
  }
  if (state.phase === PHASES.WAITING_A) {
    return "Focus done: start Break";
  }
  if (state.phase === PHASES.RUNNING_A || state.phase === PHASES.RUNNING_B) {
    if (state.paused) {
      const label = state.phase === PHASES.RUNNING_A ? "Focus" : "Break";
      return `${label} paused`;
    }
    const remainingSeconds = state.endTimestamp
      ? Math.max(0, Math.ceil((state.endTimestamp - nowMs()) / 1000))
      : 0;
    const minutes = Math.floor(remainingSeconds / 60);
    const seconds = remainingSeconds % 60;
    const label =
      state.phase === PHASES.RUNNING_A ? "Focus" : "Break";
    return `${label}: ${minutes}m ${String(seconds).padStart(2, "0")}s remaining`;
  }
  return "Focus Timer";
}

async function updateActionUI(state) {
  const color = state.paused
    ? BADGE_COLORS.paused
    : BADGE_COLORS[state.phase] || BADGE_COLORS[PHASES.IDLE];
  if (state.phase === PHASES.IDLE) {
    await chrome.action.setBadgeText({ text: "" });
  } else {
    await chrome.action.setBadgeText({ text: BADGE_TEXT_VISIBLE });
    await chrome.action.setBadgeBackgroundColor({ color });
  }
  await chrome.action.setTitle({ title: formatTitle(state) });
}

async function clearAlarm() {
  await chrome.alarms.clear(ALARM_ID);
}

async function scheduleAlarm(endTimestamp) {
  await clearAlarm();
  chrome.alarms.create(ALARM_ID, { when: endTimestamp });
}

async function ensureHeartbeatAlarm() {
  const existing = await chrome.alarms.get(HEARTBEAT_ALARM_ID);
  if (existing) return;
  chrome.alarms.create(HEARTBEAT_ALARM_ID, { periodInMinutes: 1 });
}

async function startPhase(phase, durationSeconds) {
  const endTimestamp = nowMs() + durationSeconds * 1000;
  await updateState({
    phase,
    endTimestamp,
    paused: false,
    remainingSeconds: null
  });
  await scheduleAlarm(endTimestamp);
  await ensureHeartbeatAlarm();
}

async function transitionToWaiting(phase) {
  await updateState({ phase, endTimestamp: null });
}

async function notifyPhaseComplete(phase) {
  const createNotification = async (options) => {
    try {
      await chrome.notifications.create(options);
    } catch (err) {
      console.warn("Notification failed", err);
    }
  };

  if (phase === PHASES.WAITING_A) {
    await createNotification({
      type: "basic",
      iconUrl: NOTIFICATION_ICON,
      title: "Focus Timer complete",
      message: "Click Break to start Break Timer.",
      buttons: [{ title: "OK" }],
      priority: 2,
      requireInteraction: true,
      silent: false
    });
    return;
  }
  if (phase === PHASES.RUNNING_B) {
    await createNotification({
      type: "basic",
      iconUrl: NOTIFICATION_ICON,
      title: "Break Timer complete",
      message: "Sequence finished.",
      priority: 2,
      requireInteraction: true,
      silent: false
    });
  }
}

async function handlePhaseCompletion() {
  const state = await getState();
  if (state.paused) return;
  if (state.phase === PHASES.RUNNING_A) {
    await transitionToWaiting(PHASES.WAITING_A);
    await notifyPhaseComplete(PHASES.WAITING_A);
    return;
  }

  if (state.phase === PHASES.RUNNING_B) {
    await resetToIdle();
    await notifyPhaseComplete(PHASES.RUNNING_B);
  }
}

async function handleAlarm(alarm) {
  if (alarm.name !== ALARM_ID) {
    if (alarm.name === HEARTBEAT_ALARM_ID) {
      const state = await getState();
      await updateActionUI(state);
      if (state.paused) return;
      if (
        (state.phase === PHASES.RUNNING_A || state.phase === PHASES.RUNNING_B) &&
        state.endTimestamp &&
        nowMs() >= state.endTimestamp
      ) {
        await handlePhaseCompletion();
      }
    }
    return;
  }

  const state = await getState();
  if (state.phase !== PHASES.RUNNING_A && state.phase !== PHASES.RUNNING_B) {
    return;
  }

  if (!state.endTimestamp) {
    return;
  }

  if (nowMs() >= state.endTimestamp) {
    await handlePhaseCompletion();
  } else {
    await scheduleAlarm(state.endTimestamp);
  }
}

async function startTimerA(config) {
  await setStored(STORAGE_KEYS.CONFIG, config);
  await startPhase(PHASES.RUNNING_A, config.durationASeconds);
}

async function startTimerB() {
  const config = await getConfig();
  await startPhase(PHASES.RUNNING_B, config.durationBSeconds);
}

async function resetToIdle() {
  await clearAlarm();
  await updateState({
    phase: PHASES.IDLE,
    endTimestamp: null,
    paused: false,
    remainingSeconds: null
  });
}

chrome.alarms.onAlarm.addListener(handleAlarm);

chrome.notifications.onButtonClicked.addListener(async (_notificationId, buttonIndex) => {
  const state = await getState();
  if (state.phase === PHASES.WAITING_A && buttonIndex === 0) {
    await startTimerB();
    return;
  }
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message.type === "start") {
      const config = message.config;
      const state = await getState();
      if (state.phase !== PHASES.IDLE) {
        sendResponse({ ok: false, error: "Timer already running." });
        return;
      }
      if (
        !config ||
        !Number.isFinite(config.durationASeconds) ||
        !Number.isFinite(config.durationBSeconds) ||
        config.durationASeconds < 1 ||
        config.durationBSeconds < 1
      ) {
        sendResponse({ ok: false, error: "Invalid durations." });
        return;
      }
      await startTimerA(config);
      sendResponse({ ok: true });
      return;
    }

    if (message.type === "ackA") {
      const state = await getState();
      if (state.phase === PHASES.WAITING_A) {
        await startTimerB();
        sendResponse({ ok: true });
        return;
      }
    }

    if (message.type === "pause") {
      const state = await getState();
      if (
        (state.phase === PHASES.RUNNING_A || state.phase === PHASES.RUNNING_B) &&
        state.endTimestamp &&
        !state.paused
      ) {
        const remainingSeconds = Math.max(
          1,
          Math.ceil((state.endTimestamp - nowMs()) / 1000)
        );
        await clearAlarm();
        await updateState({
          ...state,
          paused: true,
          remainingSeconds,
          endTimestamp: null
        });
        sendResponse({ ok: true });
        return;
      }
      sendResponse({ ok: false, error: "Nothing to pause." });
      return;
    }

    if (message.type === "resume") {
      const state = await getState();
      if (
        state.paused &&
        (state.phase === PHASES.RUNNING_A || state.phase === PHASES.RUNNING_B) &&
        state.remainingSeconds
      ) {
        const endTimestamp = nowMs() + state.remainingSeconds * 1000;
        await updateState({
          ...state,
          paused: false,
          endTimestamp,
          remainingSeconds: null
        });
        await scheduleAlarm(endTimestamp);
        await ensureHeartbeatAlarm();
        sendResponse({ ok: true });
        return;
      }
      sendResponse({ ok: false, error: "Nothing to resume." });
      return;
    }

    if (message.type === "cancel") {
      await resetToIdle();
      sendResponse({ ok: true });
      return;
    }

    sendResponse({ ok: false, error: "Invalid state." });
  })();

  return true;
});

async function initialize() {
  const rawConfig = await chrome.storage.local.get(STORAGE_KEYS.CONFIG);
  if (rawConfig[STORAGE_KEYS.CONFIG] === undefined) {
    await setStored(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
  }
  await ensureHeartbeatAlarm();

  const state = await getState();
  await updateActionUI(state);
  if (state.phase === PHASES.RUNNING_A || state.phase === PHASES.RUNNING_B) {
    if (state.endTimestamp && nowMs() >= state.endTimestamp) {
      await handlePhaseCompletion();
      return;
    }
    if (state.endTimestamp) {
      await scheduleAlarm(state.endTimestamp);
    }
  }
}

initialize();
