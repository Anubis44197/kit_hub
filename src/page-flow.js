function textNodes(root) {
  const nodes = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) nodes.push(walker.currentNode);
  return nodes;
}

function locateOffset(nodes, requested) {
  let remaining = Math.max(0, requested);
  for (const node of nodes) {
    const length = node.nodeValue?.length || 0;
    if (remaining <= length) return { node, offset: remaining };
    remaining -= length;
  }
  const last = nodes[nodes.length - 1];
  return last ? { node: last, offset: last.nodeValue?.length || 0 } : null;
}

function fragmentElement(source, start, end) {
  const wrapper = source.cloneNode(false);
  const nodes = textNodes(source);
  if (!nodes.length || end <= start) return wrapper;
  const from = locateOffset(nodes, start);
  const to = locateOffset(nodes, end);
  if (!from || !to) return wrapper;
  const range = document.createRange();
  range.setStart(from.node, from.offset);
  range.setEnd(to.node, to.offset);
  wrapper.appendChild(range.cloneContents());
  if (start > 0) {
    wrapper.classList.remove("first");
    wrapper.classList.add("continued");
  }
  return wrapper;
}

function lineCount(element) {
  const range = document.createRange();
  range.selectNodeContents(element);
  const tops = new Set(
    [...range.getClientRects()]
      .filter(rect => rect.width > 0.5 && rect.height > 1)
      .map(rect => Math.round(rect.top * 2) / 2)
  );
  if (tops.size) return tops.size;
  const style = getComputedStyle(element);
  const lineHeight = Number.parseFloat(style.lineHeight) || Number.parseFloat(style.fontSize) * 1.2 || 16;
  return Math.max(1, Math.round(element.getBoundingClientRect().height / lineHeight));
}

function pageOverflows(page) {
  return page.scrollHeight > page.clientHeight + 1;
}

function fittingEnd(source, start, end, page, body) {
  let low = start + 1;
  let high = end;
  let best = start;
  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    const candidate = fragmentElement(source, start, middle);
    body.appendChild(candidate);
    const fits = !pageOverflows(page);
    candidate.remove();
    if (fits) {
      best = middle;
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }
  if (best <= start) return best;
  const value = source.textContent || "";
  const boundary = value.lastIndexOf(" ", best);
  return boundary > start ? boundary : best;
}

function measureFragmentLines(source, start, end, body) {
  const candidate = fragmentElement(source, start, end);
  body.appendChild(candidate);
  const lines = lineCount(candidate);
  candidate.remove();
  return lines;
}

function previousWordBoundary(value, offset, floor) {
  let cursor = Math.max(floor, offset - 1);
  while (cursor > floor && /\s/.test(value[cursor])) cursor -= 1;
  while (cursor > floor && !/\s/.test(value[cursor - 1])) cursor -= 1;
  return cursor;
}

function adjustForWidow(source, start, split, end, body, minimumLines, diagnostics) {
  if (minimumLines <= 1 || split >= end) return split;
  const value = source.textContent || "";
  let candidate = split;
  let leadingLines = measureFragmentLines(source, start, candidate, body);
  let trailingLines = measureFragmentLines(source, candidate, end, body);
  let attempts = 0;
  while (trailingLines < minimumLines && leadingLines > minimumLines && attempts < 24) {
    const previous = previousWordBoundary(value, candidate, start);
    if (previous <= start || previous >= candidate) break;
    candidate = previous;
    leadingLines = measureFragmentLines(source, start, candidate, body);
    trailingLines = measureFragmentLines(source, candidate, end, body);
    attempts += 1;
  }
  if (candidate !== split) diagnostics.widowAdjustments += 1;
  return candidate;
}

function headingNeedsNextPage(source, nextBlock, page, body, minimumLines) {
  if (!nextBlock?.html || nextBlock.explicitBreak) return false;
  const heading = source.cloneNode(true);
  body.appendChild(heading);
  const nextSource = document.createElement("div");
  nextSource.innerHTML = nextBlock.html;
  const next = nextSource.firstElementChild;
  if (!next) {
    heading.remove();
    return false;
  }
  const style = getComputedStyle(next);
  const lineHeight = Number.parseFloat(style.lineHeight) || Number.parseFloat(style.fontSize) * 1.2 || 16;
  next.style.maxHeight = `${Math.max(1, minimumLines) * lineHeight}px`;
  next.style.overflow = "hidden";
  body.appendChild(next);
  const overflow = pageOverflows(page);
  next.remove();
  heading.remove();
  return overflow;
}

function paginate(options = {}) {
  const blocks = Array.isArray(options.blocks) ? options.blocks : [];
  const createPage = options.createPage;
  if (typeof createPage !== "function") throw new Error("Page factory is required.");
  const minimumLines = Math.max(1, Number(options.minimumLines) || 1);
  const maximumPages = Math.max(1, Number(options.maximumPages) || 400);
  const pages = [];
  const diagnostics = {
    mode: "measured-dom",
    paragraphSplits: 0,
    widowAdjustments: 0,
    headingMoves: 0,
    forcedOverflows: 0,
    truncated: false
  };
  let measurement = null;
  let pageIndex = 0;

  const openPage = () => {
    measurement = createPage(pageIndex);
    if (!measurement?.page || !measurement?.body) throw new Error("Page factory must return page and body elements.");
    document.body.appendChild(measurement.page);
  };
  const closePage = () => {
    if (!measurement) return;
    pages.push({
      html: measurement.body.innerHTML,
      blockCount: measurement.body.children.length
    });
    measurement.page.remove();
    measurement = null;
    pageIndex += 1;
  };
  const ensurePage = () => {
    if (!measurement) openPage();
  };

  try {
    ensurePage();
    for (let blockIndex = 0; blockIndex < blocks.length; blockIndex += 1) {
      if (pages.length >= maximumPages) {
        diagnostics.truncated = true;
        break;
      }
      const block = blocks[blockIndex] || {};
      if (block.explicitBreak) {
        if (measurement.body.children.length) closePage();
        ensurePage();
        continue;
      }
      const host = document.createElement("div");
      host.innerHTML = String(block.html || "").trim();
      const source = host.firstElementChild;
      if (!source) continue;

      if (block.keepWithNext && measurement.body.children.length && headingNeedsNextPage(source, blocks[blockIndex + 1], measurement.page, measurement.body, minimumLines)) {
        closePage();
        ensurePage();
        diagnostics.headingMoves += 1;
      }

      const text = source.textContent || "";
      if (!text.length) {
        measurement.body.appendChild(source.cloneNode(true));
        if (pageOverflows(measurement.page) && measurement.body.children.length > 1) {
          measurement.body.lastElementChild.remove();
          closePage();
          ensurePage();
          measurement.body.appendChild(source.cloneNode(true));
        }
        continue;
      }

      let start = 0;
      while (start < text.length) {
        if (pages.length >= maximumPages) {
          diagnostics.truncated = true;
          break;
        }
        while (start < text.length && /\s/.test(text[start])) start += 1;
        if (start >= text.length) break;
        const complete = fragmentElement(source, start, text.length);
        measurement.body.appendChild(complete);
        if (!pageOverflows(measurement.page)) {
          start = text.length;
          break;
        }
        complete.remove();

        let split = fittingEnd(source, start, text.length, measurement.page, measurement.body);
        const existingBlocks = measurement.body.children.length;
        if (split > start) {
          const fragmentLines = measureFragmentLines(source, start, split, measurement.body);
          if (existingBlocks && fragmentLines < minimumLines) split = start;
        }
        if (split > start) {
          split = adjustForWidow(source, start, split, text.length, measurement.body, minimumLines, diagnostics);
          const fragment = fragmentElement(source, start, split);
          measurement.body.appendChild(fragment);
          diagnostics.paragraphSplits += 1;
          closePage();
          ensurePage();
          start = split;
          continue;
        }

        if (existingBlocks) {
          closePage();
          ensurePage();
          continue;
        }

        measurement.body.appendChild(complete);
        diagnostics.forcedOverflows += 1;
        start = text.length;
      }
      if (diagnostics.truncated) break;
    }
    if (measurement && (measurement.body.children.length || !pages.length)) closePage();
  }
  finally {
    measurement?.page?.remove();
  }

  return { pages, diagnostics };
}

export { paginate };
