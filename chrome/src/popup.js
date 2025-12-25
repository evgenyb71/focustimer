const PHASES = {
  IDLE: "idle",
  RUNNING_A: "runningA",
  WAITING_A: "waitingForAConfirm",
  RUNNING_B: "runningB"
};

const DEFAULT_STATE = {
  phase: PHASES.IDLE,
  endTimestamp: null,
  paused: false,
  remainingSeconds: null
};

const timerAInput = document.getElementById("timerA");
const timerBInput = document.getElementById("timerB");
const startBtn = document.getElementById("startBtn");
const pauseBtn = document.getElementById("pauseBtn");
const cancelBtn = document.getElementById("cancelBtn");
const statusLabel = document.getElementById("statusLabel");
const statusTime = document.getElementById("statusTime");
const statusMessage = document.getElementById("statusMessage");

let tickInterval = null;
let currentState = DEFAULT_STATE;

function formatSeconds(totalSeconds) {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

const DEFAULT_CONFIG = {
  durationASeconds: 60,
  durationBSeconds: 60
};

function clampMinutes(value) {
  const parsed = Number.parseFloat(value);
  if (Number.isNaN(parsed) || parsed <= 0) {
    return null;
  }
  return parsed;
}

function minutesToSeconds(minutes) {
  return Math.round(minutes * 60);
}

function secondsToMinutes(seconds) {
  return Math.max(1, Math.round(seconds / 60));
}

function setButtons({ startEnabled = true }) {
  startBtn.hidden = !startEnabled;
  startBtn.disabled = !startEnabled;
}

function setInputsDisabled(isDisabled) {
  timerAInput.disabled = isDisabled;
  timerBInput.disabled = isDisabled;
}

function updateCountdown(state) {
  let remainingSeconds = 0;
  if (state.paused && state.remainingSeconds) {
    remainingSeconds = Math.max(0, Math.ceil(state.remainingSeconds));
  } else if (state.endTimestamp) {
    remainingSeconds = Math.max(
      0,
      Math.ceil((state.endTimestamp - Date.now()) / 1000)
    );
  } else {
    statusTime.textContent = "--:--";
    return;
  }
  statusTime.textContent = formatSeconds(remainingSeconds);
}

function clearTick() {
  if (tickInterval) {
    clearInterval(tickInterval);
    tickInterval = null;
  }
}

function startTick(state) {
  clearTick();
  updateCountdown(state);
  if (state.paused) {
    return;
  }
  tickInterval = setInterval(() => updateCountdown(state), 1000);
}

function render(state, config) {
  currentState = state;
  timerAInput.value = secondsToMinutes(config.durationASeconds);
  timerBInput.value = secondsToMinutes(config.durationBSeconds);

  if (state.phase === PHASES.IDLE) {
    statusLabel.textContent = "Ready";
    statusMessage.textContent = "Set durations and press Start.";
    statusTime.textContent = "--:--";
    startBtn.textContent = "Start";
    setInputsDisabled(false);
    setButtons({ startEnabled: true });
    pauseBtn.hidden = true;
    clearTick();
    return;
  }

  if (state.phase === PHASES.RUNNING_A) {
    statusLabel.textContent = state.paused ? "Focus paused" : "Focus Timer running";
    statusMessage.textContent = state.paused
      ? "Resume to continue Focus."
      : "Break Timer will wait for confirmation.";
    setInputsDisabled(true);
    startBtn.textContent = "Start Focus";
    setButtons({ startEnabled: false });
    pauseBtn.hidden = false;
    pauseBtn.textContent = state.paused ? "▶" : "||";
    startTick(state);
    return;
  }

  if (state.phase === PHASES.WAITING_A) {
    statusLabel.textContent = "Focus Timer complete";
    statusMessage.textContent = "Press Start Break to begin.";
    statusTime.textContent = "00:00";
    setInputsDisabled(true);
    startBtn.textContent = "Start Break";
    setButtons({ startEnabled: true });
    pauseBtn.hidden = true;
    clearTick();
    return;
  }

  if (state.phase === PHASES.RUNNING_B) {
    statusLabel.textContent = state.paused ? "Break paused" : "Break Timer running";
    statusMessage.textContent = state.paused
      ? "Resume to continue Break."
      : "Waiting for completion.";
    setInputsDisabled(true);
    startBtn.textContent = "Start Focus";
    setButtons({ startEnabled: false });
    pauseBtn.hidden = false;
    pauseBtn.textContent = state.paused ? "▶" : "||";
    startTick(state);
    return;
  }

}

async function loadAndRender() {
  const { config, state } = await chrome.storage.local.get(["config", "state"]);
  render(state || DEFAULT_STATE, config || DEFAULT_CONFIG);
}

startBtn.addEventListener("click", async () => {
  if (currentState.phase === PHASES.WAITING_A) {
    chrome.runtime.sendMessage({ type: "ackA" });
    return;
  }

  if (currentState.phase !== PHASES.IDLE) {
    return;
  }

  const durationAMinutes = clampMinutes(timerAInput.value);
  const durationBMinutes = clampMinutes(timerBInput.value);
  if (!durationAMinutes || !durationBMinutes) {
    statusMessage.textContent = "Durations must be at least 1 minute.";
    return;
  }

  statusMessage.textContent = "";
  // for debug, use "333" to have a short time timer
  const config = {
    durationASeconds: durationAMinutes == 333 ? 5 : minutesToSeconds(durationAMinutes),
    durationBSeconds: minutesToSeconds(durationBMinutes)
  };
  chrome.runtime.sendMessage({ type: "start", config }, (response) => {
    if (!response?.ok) {
      statusMessage.textContent = response?.error || "Unable to start.";
    }
  });
});

cancelBtn.addEventListener("click", () => {
  chrome.runtime.sendMessage({ type: "cancel" }, (response) => {
    if (!response?.ok) {
      statusMessage.textContent = response?.error || "Unable to cancel.";
      return;
    }
    loadAndRender();
  });
});

pauseBtn.addEventListener("click", () => {
  const action = currentState.paused ? "resume" : "pause";
  chrome.runtime.sendMessage({ type: action }, (response) => {
    if (!response?.ok) {
      statusMessage.textContent = response?.error || "Unable to pause/resume.";
      return;
    }
    statusMessage.textContent = "";
    loadAndRender();
  });
});

chrome.storage.onChanged.addListener(loadAndRender);

loadAndRender();
