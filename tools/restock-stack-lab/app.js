const SKUS = [
  { id: "can", name: "罐頭", en: "Canned" },
  { id: "snack", name: "零食", en: "Snacks" },
  { id: "cup", name: "杯麵", en: "Cup noodles" },
];

const BOX_SIZE = 4;
const SHELF_CAP = 12;
const SHELF_COUNT = 6;

const skuById = Object.fromEntries(SKUS.map((s) => [s.id, s]));

const state = {
  restock: { can: 99, snack: 99, cup: 99 },
  queue: [],
  shelves: Array.from({ length: SHELF_COUNT }, () => ({ sku: null, count: 0 })),
  carryCap: 16,
  log: [],
  history: [],
};

function snapshot() {
  return JSON.parse(
    JSON.stringify({
      restock: state.restock,
      queue: state.queue,
      shelves: state.shelves,
      carryCap: state.carryCap,
    })
  );
}

function pushHistory() {
  state.history.push(snapshot());
  if (state.history.length > 40) state.history.shift();
}

function log(message, kind = "ok") {
  state.log.unshift({ message, kind, t: new Date().toLocaleTimeString() });
  state.log = state.log.slice(0, 24);
}

function remainingCarry() {
  return state.carryCap - state.queue.length;
}

function groupedHud(queue) {
  const groups = [];
  for (const id of queue) {
    const last = groups[groups.length - 1];
    if (last && last.id === id) last.count += 1;
    else groups.push({ id, count: 1 });
  }
  return groups;
}

function boxesFromQueue(queue) {
  const boxes = [];
  let i = 0;
  while (i < queue.length) {
    const id = queue[i];
    let n = 0;
    while (i < queue.length && queue[i] === id && n < BOX_SIZE) {
      n += 1;
      i += 1;
    }
    boxes.push({ id, count: n });
  }
  return boxes;
}

function trailingRun(queue) {
  if (!queue.length) return { id: null, count: 0 };
  const id = queue[queue.length - 1];
  let count = 0;
  for (let i = queue.length - 1; i >= 0 && queue[i] === id; i -= 1) count += 1;
  return { id, count };
}

function pick(skuId) {
  pushHistory();
  if (state.restock[skuId] <= 0) {
    log(`${skuById[skuId].name} 補貨點已空`, "bad");
    render();
    return;
  }
  if (remainingCarry() < BOX_SIZE) {
    log(`負重已滿（${state.queue.length}/${state.carryCap}），不能再提取一箱`, "bad");
    setStatus(`負重不足：還可帶 ${remainingCarry()} 件，一箱需要 ${BOX_SIZE} 件`, "bad");
    render();
    return;
  }
  state.restock[skuId] -= 1;
  for (let i = 0; i < BOX_SIZE; i += 1) state.queue.push(skuId);
  log(`提取 ${skuById[skuId].name} 1 箱（+${BOX_SIZE} 件）。清單末項現為 ${skuById[skuId].name}`);
  setStatus(`已提取 ${skuById[skuId].name}`, "ok");
  render();
}

function stock(shelfIndex) {
  const shelf = state.shelves[shelfIndex];
  if (!state.queue.length) {
    log(`貨架 ${shelfIndex + 1}：空手，不能互動`, "bad");
    rejectShelf(shelfIndex);
    return;
  }
  const run = trailingRun(state.queue);
  if (shelf.sku && shelf.sku !== run.id) {
    log(
      `貨架 ${shelfIndex + 1} 已有 ${skuById[shelf.sku].name}，身上最後是 ${skuById[run.id].name} → ✕`,
      "bad"
    );
    rejectShelf(shelfIndex);
    return;
  }
  if (shelf.count >= SHELF_CAP) {
    log(`貨架 ${shelfIndex + 1} 已滿`, "bad");
    rejectShelf(shelfIndex);
    return;
  }

  pushHistory();
  const space = SHELF_CAP - shelf.count;
  const placed = Math.min(run.count, space);
  state.queue.splice(state.queue.length - placed, placed);
  shelf.sku = run.id;
  shelf.count += placed;
  log(
    `貨架 ${shelfIndex + 1} 上架 ${skuById[run.id].name} × ${placed}（同 SKU 連續 ${run.count}，貨架空位 ${space}）`
  );
  setStatus(`上架 ${skuById[run.id].name} × ${placed}`, "ok");
  render();
}

function rejectShelf(index) {
  const el = document.querySelector(`[data-shelf="${index}"]`);
  if (!el) return;
  el.classList.remove("reject");
  void el.offsetWidth;
  el.classList.add("reject");
  setTimeout(() => el.classList.remove("reject"), 400);
}

function loadExample() {
  pushHistory();
  state.restock = { can: 96, snack: 99, cup: 98 };
  state.queue = [];
  const order = ["can", "can", "cup", "can"];
  for (const id of order) {
    for (let i = 0; i < BOX_SIZE; i += 1) state.queue.push(id);
  }
  state.shelves = Array.from({ length: SHELF_COUNT }, () => ({ sku: null, count: 0 }));
  log("載入文件例子（乾貨對照）：罐頭×2箱、杯麵×1箱、罐頭×1箱。HUD 應顯示 罐頭×8、杯麵×4、罐頭×4。最後一箱罐頭才能先上架。");
  setStatus("已載入文件例子", "ok");
  render();
}

function undo() {
  const prev = state.history.pop();
  if (!prev) return;
  Object.assign(state, { restock: prev.restock, queue: prev.queue, shelves: prev.shelves, carryCap: prev.carryCap });
  log("Undo");
  render();
}

function reset() {
  pushHistory();
  state.restock = { can: 99, snack: 99, cup: 99 };
  state.queue = [];
  state.shelves = Array.from({ length: SHELF_COUNT }, () => ({ sku: null, count: 0 }));
  log("Reset 到 Demo v0.1 空店");
  render();
}

function setStatus(text, kind) {
  const el = document.getElementById("carry-status");
  el.textContent = text;
  el.className = `status ${kind}`;
}

function render() {
  const skuBox = document.getElementById("sku-buttons");
  skuBox.innerHTML = SKUS.map(
    (s) => `
    <button type="button" class="sku ${s.id}" data-pick="${s.id}">
      <span><span class="swatch"></span>${s.name} <small>${s.en}</small></span>
      <strong>${state.restock[s.id]} 箱</strong>
    </button>`
  ).join("");

  const stack = document.getElementById("box-stack");
  const boxes = boxesFromQueue(state.queue);
  stack.innerHTML = boxes
    .map((b) => `<div class="crate ${b.id}">${skuById[b.id].name}</div>`)
    .join("");

  const groups = groupedHud(state.queue);
  const hud = document.getElementById("hud-list");
  const empty = document.getElementById("hud-empty");
  hud.innerHTML = groups
    .map(
      (g, i) =>
        `<li class="${g.id}${i === groups.length - 1 ? " tail" : ""}">${skuById[g.id].name} × ${g.count}</li>`
    )
    .join("");
  empty.hidden = groups.length > 0;

  const grid = document.getElementById("shelf-grid");
  grid.innerHTML = state.shelves
    .map((shelf, i) => {
      const label = shelf.sku ? `${skuById[shelf.sku].name} × ${shelf.count}` : "空架";
      const pct = (shelf.count / SHELF_CAP) * 100;
      const color = shelf.sku ? `var(--${shelf.sku === "can" ? "can" : shelf.sku === "snack" ? "snack" : "cup"})` : "#3a2e24";
      return `
        <button type="button" class="shelf" data-shelf="${i}">
          <div class="name">貨架 ${i + 1}</div>
          <div class="fill"><span style="width:${pct}%;background:${color}"></span></div>
          <strong>${label}</strong>
          <div>${shelf.count}/${SHELF_CAP}</div>
          <div class="xmark">✕</div>
        </button>`;
    })
    .join("");

  document.getElementById("log").innerHTML = state.log
    .map((row) => `<li class="${row.kind}">${row.t} — ${row.message}</li>`)
    .join("");

  const countEl = document.getElementById("carry-count");
  countEl.textContent = `攜帶 ${state.queue.length}/${state.carryCap} 件`;
  countEl.className = remainingCarry() < BOX_SIZE ? "status bad" : "status ok";
}

document.addEventListener("click", (e) => {
  const pickBtn = e.target.closest("[data-pick]");
  if (pickBtn) pick(pickBtn.dataset.pick);
  const shelfBtn = e.target.closest("[data-shelf]");
  if (shelfBtn) stock(Number(shelfBtn.dataset.shelf));
});

document.getElementById("btn-example").addEventListener("click", loadExample);
document.getElementById("btn-undo").addEventListener("click", undo);
document.getElementById("btn-reset").addEventListener("click", reset);
document.getElementById("carry-cap").addEventListener("change", (e) => {
  pushHistory();
  state.carryCap = Math.max(4, Number(e.target.value) || 16);
  log(`負重上限改為 ${state.carryCap} 件`);
  render();
});

render();
setStatus(`攜帶 0/${state.carryCap} 件`, "ok");
