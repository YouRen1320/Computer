// The static shell renders only generated catalog metadata. Chapter prose remains
// unavailable until its catalog status passes the publication gate.
async function loadCatalog() {
  const response = await fetch("generated/catalog.json", { cache: "no-store" });
  if (!response.ok) throw new Error(`目录读取失败：HTTP ${response.status}`);
  return response.json();
}

function renderSummary(catalog) {
  const cards = [
    ["章节总数", catalog.chapter_count],
    ["可发布", catalog.publishable_count],
    ["卷数", catalog.volumes.length]
  ];
  document.querySelector("#summary").replaceChildren(
    ...cards.map(([label, value]) => {
      const card = document.createElement("div");
      card.className = "summary-card";
      const count = document.createElement("strong");
      count.textContent = value;
      const caption = document.createElement("span");
      caption.textContent = label;
      card.append(count, caption);
      return card;
    })
  );
}

function renderVolumes(catalog) {
  const nodes = catalog.volumes.map((volume) => {
    const panel = document.createElement("details");
    panel.className = "volume";
    const heading = document.createElement("summary");
    heading.textContent = `卷 ${volume.id}：${volume.title}（${volume.chapters.length} 章）`;
    const list = document.createElement("ol");
    list.className = "chapter-list";

    for (const chapter of volume.chapters) {
      const item = document.createElement("li");
      const title = document.createElement("span");
      title.textContent = `${chapter.id} · ${chapter.title} `;
      const status = document.createElement("span");
      status.className = `status status--${chapter.status}`;
      status.textContent = chapter.status;
      item.append(title, status);
      list.append(item);
    }
    panel.append(heading, list);
    return panel;
  });
  document.querySelector("#volumes").replaceChildren(...nodes);
}

loadCatalog()
  .then((catalog) => {
    document.querySelector("#edition").textContent = `版本 ${catalog.edition} · 仅 verified 章节可发布`;
    renderSummary(catalog);
    renderVolumes(catalog);
  })
  .catch((error) => {
    const message = document.createElement("p");
    message.className = "error";
    message.textContent = `${error.message}。请先运行构建命令，并通过 HTTP 服务器打开本页。`;
    document.querySelector("main").prepend(message);
  });
