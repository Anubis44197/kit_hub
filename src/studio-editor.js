import MarkdownIt from "markdown-it";
import { Schema, DOMParser as ProseMirrorDOMParser } from "prosemirror-model";
import { EditorState, TextSelection } from "prosemirror-state";
import { EditorView } from "prosemirror-view";
import {
  baseKeymap,
  lift,
  setBlockType,
  toggleMark,
  wrapIn
} from "prosemirror-commands";
import { history, redo, undo } from "prosemirror-history";
import { keymap } from "prosemirror-keymap";
import { defaultMarkdownSerializer, MarkdownSerializer } from "prosemirror-markdown";
import { schema as basicSchema } from "prosemirror-schema-basic";
import { addListNodes, liftListItem, wrapInList } from "prosemirror-schema-list";

const nodes = addListNodes(basicSchema.spec.nodes, "paragraph block*", "block");
const marks = basicSchema.spec.marks.addToEnd("underline", {
  parseDOM: [{ tag: "u" }],
  toDOM() { return ["u", 0]; }
});
const schema = new Schema({ nodes, marks });
const markdown = new MarkdownIt({ html: true, linkify: false, typographer: false });
const serializer = new MarkdownSerializer(
  { ...defaultMarkdownSerializer.nodes },
  {
    ...defaultMarkdownSerializer.marks,
    underline: {
      open: "<u>",
      close: "</u>",
      mixable: true,
      expelEnclosingWhitespace: true
    }
  }
);

function documentFromMarkdown(value) {
  const host = document.createElement("div");
  host.innerHTML = markdown.render(String(value || ""));
  return ProseMirrorDOMParser.fromSchema(schema).parse(host);
}

function markdownFromDocument(doc) {
  return serializer.serialize(doc, { tightLists: true });
}

function commandResult(command, state, dispatch, view) {
  return Boolean(command && command(state, dispatch, view));
}

function mount(element, options = {}) {
  if (!element) throw new Error("Structured editor mount element is required.");
  const emit = typeof options.onChange === "function" ? options.onChange : () => {};
  const emitSelection = typeof options.onSelectionChange === "function" ? options.onSelectionChange : () => {};
  let suppressChange = false;
  const plugins = [
    history(),
    keymap({
      "Mod-b": toggleMark(schema.marks.strong),
      "Mod-i": toggleMark(schema.marks.em),
      "Mod-u": toggleMark(schema.marks.underline),
      "Mod-z": undo,
      "Mod-y": redo,
      "Shift-Mod-z": redo
    }),
    keymap(baseKeymap)
  ];
  let state = EditorState.create({
    schema,
    doc: documentFromMarkdown(options.markdown || ""),
    plugins
  });
  const view = new EditorView(element, {
    state,
    dispatchTransaction(transaction) {
      const selectionChanged = !transaction.selection.eq(view.state.selection);
      state = view.state.apply(transaction);
      view.updateState(state);
      if (transaction.docChanged && !suppressChange) {
        emit(markdownFromDocument(state.doc), api);
      }
      if (selectionChanged) emitSelection(api);
    },
    attributes: {
      "aria-label": options.ariaLabel || "Yapılandırılmış bölüm editörü",
      lang: options.lang || "tr",
      spellcheck: "true"
    }
  });

  const apply = command => commandResult(command, view.state, view.dispatch, view);
  const setMarkdown = (value, { emitChange = false } = {}) => {
    const next = String(value || "");
    if (next === markdownFromDocument(view.state.doc)) return;
    suppressChange = true;
    const nextState = EditorState.create({ schema, doc: documentFromMarkdown(next), plugins });
    state = nextState;
    view.updateState(nextState);
    suppressChange = false;
    if (emitChange) emit(markdownFromDocument(nextState.doc), api);
  };
  const setBlock = kind => {
    if (kind === "heading") return apply(setBlockType(schema.nodes.heading, { level: 1 }));
    if (kind === "blockquote") return apply(wrapIn(schema.nodes.blockquote));
    if (kind === "bullet_list") return apply(wrapInList(schema.nodes.bullet_list));
    if (kind === "lift_list") return apply(liftListItem(schema.nodes.list_item));
    if (kind === "lift") return apply(lift);
    return apply(setBlockType(schema.nodes.paragraph));
  };
  const selectedText = () => {
    const { from, to } = view.state.selection;
    return from === to ? "" : view.state.doc.textBetween(from, to, "\n");
  };
  const isActive = name => {
    const mark = schema.marks[name];
    if (mark) {
      const { from, to, empty, $from } = view.state.selection;
      if (empty) return Boolean(mark.isInSet(view.state.storedMarks || $from.marks()));
      return view.state.doc.rangeHasMark(from, to, mark);
    }
    const node = view.state.selection.$from.parent;
    if (name === "heading") return node.type === schema.nodes.heading;
    if (name === "blockquote") {
      for (let depth = view.state.selection.$from.depth; depth > 0; depth -= 1) {
        if (view.state.selection.$from.node(depth).type === schema.nodes.blockquote) return true;
      }
    }
    return name === "paragraph" && node.type === schema.nodes.paragraph;
  };
  const selectionContext = () => {
    const { $from, from, to } = view.state.selection;
    const block = $from.parent;
    return {
      from,
      to,
      selectedText: selectedText(),
      blockText: block?.textContent || ""
    };
  };
  const selectText = (query, occurrence = 0) => {
    const needle = String(query || "");
    if (!needle) return false;
    let seen = 0;
    let match = null;
    view.state.doc.descendants((node, pos) => {
      if (match || !node.isText || !node.text) return;
      let offset = node.text.indexOf(needle);
      while (offset >= 0) {
        if (seen === occurrence) {
          match = { from: pos + offset, to: pos + offset + needle.length };
          return false;
        }
        seen += 1;
        offset = node.text.indexOf(needle, offset + Math.max(1, needle.length));
      }
    });
    if (!match) return false;
    view.dispatch(view.state.tr.setSelection(TextSelection.create(view.state.doc, match.from, match.to)).scrollIntoView());
    view.focus();
    return true;
  };
  const run = (name, payload) => {
    if (name === "bold") return apply(toggleMark(schema.marks.strong));
    if (name === "italic") return apply(toggleMark(schema.marks.em));
    if (name === "underline") return apply(toggleMark(schema.marks.underline));
    if (name === "undo") return apply(undo);
    if (name === "redo") return apply(redo);
    if (name === "paragraph" || name === "heading" || name === "blockquote" || name === "bullet_list" || name === "lift_list" || name === "lift") return setBlock(name);
    if (name === "replaceSelection") {
      view.dispatch(view.state.tr.insertText(String(payload || "")).scrollIntoView());
      view.focus();
      return true;
    }
    if (name === "replaceCurrentBlock") {
      const { $from } = view.state.selection;
      view.dispatch(view.state.tr.insertText(String(payload || ""), $from.start(), $from.end()).scrollIntoView());
      view.focus();
      return true;
    }
    return false;
  };

  const api = {
    destroy: () => view.destroy(),
    focus: () => view.focus(),
    getJSON: () => view.state.doc.toJSON(),
    getMarkdown: () => markdownFromDocument(view.state.doc),
    getPlainText: () => view.state.doc.textBetween(0, view.state.doc.content.size, "\n\n"),
    getSelectedText: selectedText,
    getSelectionContext: selectionContext,
    isActive,
    run,
    selectText,
    setEditable(editable) { view.setProps({ editable: () => Boolean(editable) }); },
    setMarkdown
  };
  return api;
}

window.KitHubStructuredEditor = Object.freeze({ mount, schemaVersion: "1.0.0" });
