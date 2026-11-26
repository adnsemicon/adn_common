import argparse
import re
import sys
import os

from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, List, Optional, Tuple


def file_exists(filepath):
    return os.path.isfile(filepath)


# DRAW INPUT LEFT
def draw_port_IL(x, y):
    return f'<polygon points="{x+00},{y+10} {x+00},{y+00} {x+20},{y+00} {x+30},{y+10} {x+50},{y+10} {x+30},{y+10} {x+20},{y+20} {x+00},{y+20} {x+00},{y+10}"/>\n'


# DRAW INOUT LEFT
def draw_port_IOL(x, y):
    return f'<polygon points="{x+00},{y+10} {x+10},{y+00} {x+20},{y+00} {x+30},{y+10} {x+50},{y+10} {x+30},{y+10} {x+20},{y+20} {x+10},{y+20} {x+00},{y+10}"/>\n'


# DRAW OUTPUT LEFT
def draw_port_OL(x, y):
    return f'<polygon points="{x+00},{y+10} {x+10},{y+00} {x+30},{y+00} {x+30},{y+10} {x+50},{y+10} {x+30},{y+10} {x+30},{y+20} {x+10},{y+20} {x+00},{y+10}"/>\n'


# DRAW INPUT RIGHT
def draw_port_IR(x, y):
    return f'<polygon points="{x+00},{y+10} {x+20},{y+10} {x+30},{y+00} {x+50},{y+00} {x+50},{y+10} {x+50},{y+20} {x+30},{y+20} {x+20},{y+10} {x+00},{y+10}"/>\n'


# DRAW INOUT RIGHT
def draw_port_IOR(x, y):
    return f'<polygon points="{x+00},{y+10} {x+20},{y+10} {x+30},{y+00} {x+40},{y+00} {x+50},{y+10} {x+40},{y+20} {x+30},{y+20} {x+20},{y+10} {x+00},{y+10}"/>\n'


# DRAW OUTPUT RIGHT
def draw_port_OR(x, y):
    return f'<polygon points="{x+00},{y+10} {x+20},{y+10} {x+20},{y+00} {x+40},{y+00} {x+50},{y+10} {x+40},{y+20} {x+20},{y+20} {x+20},{y+10} {x+00},{y+10}"/>\n'


# DRAW TEXT LEFT
def draw_TEXT_L(text, x, y):
    return f'<text x="{x}" y="{y}" dominant-baseline="hanging" text-anchor="start" font-size="20" style="fill:black;stroke:black;stroke-width:0">{text}</text>\n'


# DRAW TEXT RIGHT
def draw_TEXT_R(text, x, y):
    return f'<text x="{x}" y="{y}" dominant-baseline="hanging" text-anchor="end" font-size="20" style="fill:black;stroke:black;stroke-width:0">{text}</text>\n'

# DRAW TEXT RIGHT
def draw_TEXT_Title(text, x, y):
    return f'<text x="{x}" y="{y}" dominant-baseline="hanging" text-anchor="middle" font-size="30" style="fill:black;stroke:black;stroke-width:0">{text}</text>\n'



IDENTIFIER_RE = re.compile(r"[A-Za-z_]\w*")
TOP_COMMENT_RE = re.compile(r"^\s*/\*(.*?)\*/", flags=re.DOTALL)
INLINE_COMMENT_RE = re.compile(r"//.*")
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", flags=re.DOTALL)


@dataclass
class Parameter:
    name: str
    type_text: str = ""
    dimension: str = ""
    default: str = ""
    description: str = ""


@dataclass
class Port:
    name: str
    direction: str = "interface"
    type_text: str = ""
    dimension: str = ""
    description: str = ""
    group: int = 0


@dataclass
class Macro:
    name: str
    args: str = ""
    body_preview: str = ""
    description: str = ""


@dataclass
class DocumentModel:
    source_path: Path
    kind: str = "unknown"
    name: str = ""
    author: str = ""
    description: str = ""
    parameters: List[Parameter] = field(default_factory=list)
    ports: List[Port] = field(default_factory=list)
    typedefs: List[str] = field(default_factory=list)
    macros: List[Macro] = field(default_factory=list)
    include_guard: str = ""


def normalize_lines(text: str) -> List[str]:
    return [line.rstrip("\n").rstrip(" ").replace("\t", " ") for line in text.splitlines()]


def remove_comments(text: str) -> str:
    no_block = BLOCK_COMMENT_RE.sub("", text)
    return re.sub(r"//.*", "", no_block)


def extract_header_info(text: str) -> Tuple[str, str, str]:
    author = ""
    description = ""
    remainder = text

    match = TOP_COMMENT_RE.match(text)
    if not match:
        return author, description, remainder

    raw_header = match.group(1)
    remainder = text[match.end() :]

    lines = [line.strip() for line in raw_header.splitlines()]
    cleaned: List[str] = []
    for line in lines:
        if not line:
            cleaned.append("")
            continue
        if line.startswith("*"):
            line = line[1:].strip()

        if "Author" in line and ":" in line:
            author = line.split(":", 1)[1].strip()

        # Keep meaningful documentation lines, ignore boilerplate copyright/license lines.
        if re.search(r"copyright|licensed under|see license|this file is part", line, flags=re.IGNORECASE):
            continue
        cleaned.append(line)

    description = "\n".join(cleaned).strip()
    return author, description, remainder


def extract_balanced_block(text: str, start_idx: int, open_ch: str = "(", close_ch: str = ")") -> Tuple[str, int]:
    if start_idx >= len(text) or text[start_idx] != open_ch:
        return "", start_idx

    depth = 0
    for idx in range(start_idx, len(text)):
        ch = text[idx]
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return text[start_idx : idx + 1], idx + 1
    return "", start_idx


def split_top_level_csv(text: str) -> List[str]:
    items: List[str] = []
    cur: List[str] = []
    p = b = c = 0

    for ch in text:
        if ch == "(":
            p += 1
        elif ch == ")":
            p -= 1
        elif ch == "[":
            b += 1
        elif ch == "]":
            b -= 1
        elif ch == "{":
            c += 1
        elif ch == "}":
            c -= 1

        if ch == "," and p == 0 and b == 0 and c == 0:
            item = "".join(cur).strip()
            if item:
                items.append(item)
            cur = []
            continue

        cur.append(ch)

    tail = "".join(cur).strip()
    if tail:
        items.append(tail)
    return items


def split_top_level_csv_with_prefix(text: str) -> List[Tuple[str, str]]:
    items: List[Tuple[str, str]] = []
    cur: List[str] = []
    p = b = c = 0
    token_start = 0

    for i, ch in enumerate(text):
        if ch == "(":
            p += 1
        elif ch == ")":
            p -= 1
        elif ch == "[":
            b += 1
        elif ch == "]":
            b -= 1
        elif ch == "{":
            c += 1
        elif ch == "}":
            c -= 1

        if ch == "," and p == 0 and b == 0 and c == 0:
            raw_item = "".join(cur)
            trimmed = raw_item.strip()
            if trimmed:
                prefix = text[token_start : token_start + len(raw_item) - len(raw_item.lstrip())]
                items.append((prefix, trimmed))
            cur = []
            token_start = i + 1
            continue

        cur.append(ch)

    raw_tail = "".join(cur)
    tail = raw_tail.strip()
    if tail:
        prefix = text[token_start : token_start + len(raw_tail) - len(raw_tail.lstrip())]
        items.append((prefix, tail))
    return items


def strip_inline_comment(line: str) -> str:
    return INLINE_COMMENT_RE.sub("", line)


def build_first_seen_index(lines: List[str]) -> dict:
    index = {}
    for i, line in enumerate(lines):
        code = strip_inline_comment(line)
        for token in IDENTIFIER_RE.findall(code):
            if token not in index:
                index[token] = i
    return index


def symbol_description(symbol: str, lines: List[str], first_seen: dict) -> str:
    idx = first_seen.get(symbol)
    if idx is None:
        return ""

    if "//" in lines[idx]:
        return lines[idx].split("//", 1)[1].strip()

    desc_parts: List[str] = []
    i = idx - 1
    while i >= 0:
        stripped = lines[i].strip()
        if stripped.startswith("//"):
            desc_parts.insert(0, stripped[2:].strip())
            i -= 1
            continue
        break
    return " ".join(desc_parts).strip()


def clean_block_comment_text(lines: List[str]) -> str:
    cleaned: List[str] = []
    for line in lines:
        text = line.strip()
        text = text.replace("/*", "").replace("*/", "").strip()
        if text.startswith("*"):
            text = text[1:].strip()
        if text:
            cleaned.append(text)
    return " ".join(cleaned).strip()


def parse_param_item(item: str) -> Optional[Parameter]:
    item = item.strip()
    if not item:
        return None

    item = re.sub(r"^\s*(parameter|localparam)\s+", "", item)

    default = ""
    left = item
    if "=" in item:
        left, _, right = item.partition("=")
        default = right.strip()

    left = left.strip()
    match = re.search(r"([A-Za-z_]\w*)\s*(\[[^\]]*\])?\s*$", left)
    if not match:
        return None

    name = match.group(1)
    dim = (match.group(2) or "").strip()
    type_text = left[: match.start(1)].strip()
    return Parameter(name=name, type_text=type_text, dimension=dim, default=default)


def parse_port_item(item: str) -> Optional[Port]:
    item = item.strip()
    if not item:
        return None

    item = re.sub(r"\b(signed|unsigned|var|wire|logic|reg)\b", lambda m: m.group(0), item)
    tokens = item.split()
    if not tokens:
        return None

    direction = "interface"
    for candidate in ("input", "output", "inout", "ref"):
        if re.search(r"\b" + candidate + r"\b", item):
            direction = candidate
            break

    name_match = re.search(r"([A-Za-z_]\w*)\s*(\[[^\]]*\])?\s*$", item)
    if not name_match:
        return None

    name = name_match.group(1)
    dim = (name_match.group(2) or "").replace(" ", "")

    prefix = item[: name_match.start(1)].strip()
    type_text = re.sub(r"\b(input|output|inout|ref)\b", "", prefix)
    type_text = " ".join(type_text.split())
    return Port(name=name, direction=direction, type_text=type_text, dimension=dim)


def parse_module_like(model: DocumentModel, raw_text: str, lines: List[str], first_seen: dict) -> bool:
    text = remove_comments(raw_text)
    m = re.search(r"\b(module|program|interface)\s+([A-Za-z_]\w*)", text)
    if not m:
        return False

    model.kind = m.group(1)
    model.name = m.group(2)
    pos = m.end()

    while True:
        rest = text[pos:].lstrip()
        if not rest.startswith("import"):
            break
        sem = rest.find(";")
        if sem < 0:
            break
        pos += len(text[pos:]) - len(rest) + sem + 1

    rest = text[pos:].lstrip()
    pos = len(text) - len(rest)

    if pos < len(text) and text[pos] == "#":
        p_start = text.find("(", pos)
        if p_start >= 0:
            p_block, next_pos = extract_balanced_block(text, p_start)
            if p_block:
                for item in split_top_level_csv(p_block[1:-1]):
                    parsed = parse_param_item(item)
                    if parsed:
                        parsed.description = symbol_description(parsed.name, lines, first_seen)
                        model.parameters.append(parsed)
                pos = next_pos

    rest = text[pos:].lstrip()
    pos = len(text) - len(rest)

    if pos < len(text) and text[pos] == "(":
        ports_block, _ = extract_balanced_block(text, pos)
        if ports_block:
            inherited_direction = ""
            current_group = -1
            for prefix, item in split_top_level_csv_with_prefix(ports_block[1:-1]):
                parsed = parse_port_item(item)
                if parsed:
                    if current_group < 0 or "\n\n" in prefix:
                        current_group += 1
                        inherited_direction = ""

                    # In ANSI style port lists, only the first port in a declaration group
                    # may carry direction; following ports inherit that group direction.
                    if parsed.direction == "interface" and inherited_direction:
                        parsed.direction = inherited_direction
                    elif parsed.direction in {"input", "output", "inout", "ref"}:
                        inherited_direction = parsed.direction

                    parsed.group = max(0, current_group)
                    parsed.description = symbol_description(parsed.name, lines, first_seen)
                    model.ports.append(parsed)

    return True


def split_top_level_statements(text: str) -> List[str]:
    statements: List[str] = []
    cur: List[str] = []
    p = b = c = 0

    for ch in text:
        if ch == "(":
            p += 1
        elif ch == ")":
            p -= 1
        elif ch == "[":
            b += 1
        elif ch == "]":
            b -= 1
        elif ch == "{":
            c += 1
        elif ch == "}":
            c -= 1

        cur.append(ch)
        if ch == ";" and p == 0 and b == 0 and c == 0:
            stmt = "".join(cur).strip()
            if stmt:
                statements.append(stmt)
            cur = []

    tail = "".join(cur).strip()
    if tail:
        statements.append(tail)
    return statements


def parse_package(model: DocumentModel, raw_text: str, lines: List[str], first_seen: dict) -> bool:
    text = remove_comments(raw_text)
    m = re.search(r"\bpackage\s+([A-Za-z_]\w*)\s*;", text)
    if not m:
        return False

    model.kind = "package"
    model.name = m.group(1)

    body_start = m.end()
    body_end_match = re.search(r"\bendpackage\b", text[body_start:])
    body_end = body_start + body_end_match.start() if body_end_match else len(text)
    body = text[body_start:body_end]

    for statement in split_top_level_statements(body):
        stripped = statement.strip().rstrip(";")
        if not stripped:
            continue

        if stripped.startswith("parameter") or stripped.startswith("localparam"):
            for item in split_top_level_csv(stripped):
                parsed = parse_param_item(item)
                if parsed:
                    parsed.description = symbol_description(parsed.name, lines, first_seen)
                    model.parameters.append(parsed)

    for tname in re.findall(r"typedef\s+struct\s+packed\s*\{.*?\}\s*([A-Za-z_]\w*)\s*;", body, flags=re.DOTALL):
        model.typedefs.append(tname)

    return True


def parse_include(model: DocumentModel, raw_text: str, lines: List[str], first_seen: dict) -> bool:
    suffix = model.source_path.suffix.lower()
    stripped = raw_text.lstrip()
    if suffix not in {".svh", ".vh"} and "`define" not in raw_text:
        return False

    model.kind = "include"
    model.name = model.source_path.stem

    guard_ifndef = None
    guard_define = None
    pending_line_comments: List[str] = []
    pending_block_comment = ""

    i = 0
    while i < len(lines):
        stripped_line = lines[i].strip()

        if stripped_line.startswith("/*"):
            block_lines = [lines[i]]
            while "*/" not in lines[i] and i + 1 < len(lines):
                i += 1
                block_lines.append(lines[i])
            pending_block_comment = clean_block_comment_text(block_lines)
            pending_line_comments = []
            i += 1
            continue

        if stripped_line.startswith("//"):
            pending_line_comments.append(stripped_line[2:].strip())
            i += 1
            continue

        if stripped_line == "":
            i += 1
            continue

        if stripped_line.startswith("`ifndef ") and guard_ifndef is None:
            guard_ifndef = stripped_line.split(None, 1)[1].strip()
        elif stripped_line.startswith("`define ") and guard_define is None:
            guard_define = stripped_line.split(None, 1)[1].strip().split()[0]

        if not stripped_line.startswith("`define "):
            i += 1
            continue

        start = i
        macro_lines = [stripped_line]
        while macro_lines[-1].rstrip().endswith("\\") and i + 1 < len(lines):
            i += 1
            macro_lines.append(lines[i].rstrip())

        define_head = macro_lines[0][len("`define ") :].strip()
        m = re.match(r"([A-Za-z_]\w*)(?:\((.*?)\))?\s*(.*)", define_head)
        if m:
            name = m.group(1)
            args = (m.group(2) or "").strip()
            body_text = " ".join(line.strip().rstrip("\\") for line in macro_lines)
            body_text = body_text[:160]

            # Filter out include-guard helper macro to keep macro table focused on functional content.
            if guard_ifndef and name == guard_ifndef and args == "":
                pending_line_comments = []
                pending_block_comment = ""
                i += 1
                continue

            desc = symbol_description(name, lines, first_seen)
            if not desc:
                if pending_block_comment:
                    desc = pending_block_comment
                elif pending_line_comments:
                    desc = " ".join(pending_line_comments).strip()
            model.macros.append(Macro(name=name, args=args, body_preview=body_text, description=desc))

            pending_line_comments = []
            pending_block_comment = ""

        i += 1

    if guard_ifndef and guard_define and guard_ifndef == guard_define:
        model.include_guard = guard_ifndef

    return True


def parse_unknown(model: DocumentModel) -> None:
    if not model.name:
        model.name = model.source_path.stem
    if not model.kind:
        model.kind = "unknown"


def markdown_escape(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ").strip()


def render_table(headers: List[str], rows: List[List[str]]) -> str:
    if not rows:
        return "_None_\n\n"

    out = "|" + "|".join(headers) + "|\n"
    out += "|" + "|".join(["-" for _ in headers]) + "|\n"
    for row in rows:
        out += "|" + "|".join(markdown_escape(col) for col in row) + "|\n"
    out += "\n"
    return out


def render_top_io_svg(model: DocumentModel, output_dir: Path) -> None:
    if model.kind not in {"module", "program", "interface"}:
        return

    grouped: List[Tuple[int, List[int]]] = []
    for idx, port in enumerate(model.ports):
        if not grouped or grouped[-1][0] != port.group:
            grouped.append((port.group, [idx]))
        else:
            grouped[-1][1].append(idx)

    left_indices: List[Optional[int]] = []
    right_indices: List[Optional[int]] = []
    for _, indices in grouped:
        if not indices:
            continue
        first_port = model.ports[indices[0]]
        target = left_indices if first_port.direction == "input" else right_indices
        if target:
            # Insert one pin-space gap between functional groups.
            target.append(None)
        target.extend(indices)

    # First align bottoms between left/right by padding the shorter side on top.
    if len(left_indices) > len(right_indices):
        right_indices = ([None] * (len(left_indices) - len(right_indices))) + right_indices
    elif len(right_indices) > len(left_indices):
        left_indices = ([None] * (len(right_indices) - len(left_indices))) + left_indices

    max_len = max(4, len(left_indices), len(right_indices))
    max_left_name_len = max((len(model.ports[i].name) for i in left_indices if i is not None), default=0)
    max_right_name_len = max((len(model.ports[i].name) for i in right_indices if i is not None), default=0)
    while len(left_indices) < max_len:
        left_indices.append(None)
    while len(right_indices) < max_len:
        right_indices.append(None)

    out_path = output_dir / f"{model.name}_top.svg"
    with out_path.open("w", encoding="utf-8") as write_file:
        side = len(left_indices)

        # Keep a minimum center gap between left and right labels so they do not overlap.
        char_width_px = 12
        text_gap_px = 30
        base_box_width = side * 50 + 25
        text_driven_box_width = 10 + (max_left_name_len * char_width_px) + text_gap_px + (max_right_name_len * char_width_px)
        box_width = max(base_box_width, text_driven_box_width)

        svg_width = box_width + 115
        svg_height = 140 + side * 50

        write_file.write(f'<svg height="{svg_height}" width="{svg_width}" xmlns="http://www.w3.org/2000/svg">\n')
        write_file.write('<rect width="100%" height="100%" x="0" y="0" style="fill:white;stroke:white;stroke-width:0"/>\n')
        write_file.write('<g style="fill:white;stroke:black;stroke-width:1">\n')
        write_file.write(f'<rect width="{box_width}" height="{side * 50 + 25}" x="60" y="60"/>\n')

        x = 10
        y = 85
        for idx in left_indices:
            if idx is not None:
                port = model.ports[idx]
                if port.direction == "input":
                    write_file.write(draw_port_IL(x, y))
                elif port.direction == "output":
                    write_file.write(draw_port_OL(x, y))
                else:
                    write_file.write(draw_port_IOL(x, y))
                write_file.write(draw_TEXT_L(port.name, x + 55, y))
            y += 50

        x = box_width + 60
        y = 85
        for idx in right_indices:
            if idx is not None:
                port = model.ports[idx]
                if port.direction == "input":
                    write_file.write(draw_port_IR(x, y))
                elif port.direction == "output":
                    write_file.write(draw_port_OR(x, y))
                else:
                    write_file.write(draw_port_IOR(x, y))
                write_file.write(draw_TEXT_R(port.name, x - 5, y))
            y += 50

        write_file.write(draw_TEXT_Title(model.name, 60 + (box_width // 2), 100 + side * 50))
        write_file.write("</g>\n</svg>\n")


def render_markdown(model: DocumentModel, output_dir: Path, emit_svg: bool) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)

    title_name = model.name or model.source_path.stem
    out_path = output_dir / f"{title_name}.md"

    lines: List[str] = []
    lines.append(f"# {title_name} ({model.kind})\n")

    if model.author:
        lines.append(f"### Author: {model.author}\n")

    lines.append(f"### Source: {model.source_path.name}\n")

    if model.kind in {"module", "program", "interface"} and emit_svg:
        lines.append("## Top IO\n")
        lines.append(f"<img src=\"./{title_name}_top.svg\">\n")

        des_svg = output_dir / f"{title_name}_des.svg"
        if file_exists(str(des_svg)):
            lines.append(f"<img src=\"./{title_name}_des.svg\">\n")

    lines.append("## Parameters\n")
    lines.append(
        render_table(
            ["Name", "Type", "Dimension", "Default", "Description"],
            [[p.name, p.type_text, p.dimension, p.default, p.description] for p in model.parameters],
        )
    )

    if model.ports:
        lines.append("## Ports\n")
        lines.append(
            render_table(
                ["Name", "Direction", "Type", "Dimension", "Description"],
                [[p.name, p.direction, p.type_text, p.dimension, p.description] for p in model.ports],
            )
        )

    if model.typedefs:
        lines.append("## Typedefs\n")
        lines.append(render_table(["Name"], [[t] for t in model.typedefs]))

    if model.include_guard:
        lines.append("## Include Guard\n")
        lines.append(f"{model.include_guard}\n\n")

    if model.macros:
        lines.append("## Macros\n")
        lines.append(
            render_table(
                ["Name", "Args", "Description", "Preview"],
                [[m.name, m.args, m.description, m.body_preview] for m in model.macros],
            )
        )

    lines.append("## Description\n")
    if model.description:
        lines.append(model.description + "\n")
    else:
        lines.append("_No top-level description found._\n")

    out_path.write_text("\n".join(lines), encoding="utf-8")

    if emit_svg:
        render_top_io_svg(model, output_dir)

    return out_path


def build_document_model(path: Path) -> DocumentModel:
    raw_text = path.read_text(encoding="utf-8")
    lines = normalize_lines(raw_text)

    model = DocumentModel(source_path=path)
    model.author, model.description, _ = extract_header_info(raw_text)

    first_seen = build_first_seen_index(lines)

    parsed = False
    parsed = parse_module_like(model, raw_text, lines, first_seen) or parsed
    if not parsed:
        parsed = parse_package(model, raw_text, lines, first_seen) or parsed
    if not parsed:
        parsed = parse_include(model, raw_text, lines, first_seen) or parsed
    if not parsed:
        parse_unknown(model)

    if not model.name:
        model.name = path.stem

    return model


def collect_input_files(inputs: Iterable[str], recursive: bool) -> List[Path]:
    files: List[Path] = []
    seen = set()
    supported_ext = {".sv", ".svh", ".vh", ".v"}

    for item in inputs:
        p = Path(item)
        if p.is_file():
            if p.suffix.lower() in supported_ext and p.resolve() not in seen:
                files.append(p)
                seen.add(p.resolve())
            continue

        if p.is_dir():
            pattern = "**/*" if recursive else "*"
            for child in p.glob(pattern):
                if child.is_file() and child.suffix.lower() in supported_ext:
                    rp = child.resolve()
                    if rp not in seen:
                        files.append(child)
                        seen.add(rp)
            continue

        for candidate in Path(".").glob(item):
            if candidate.is_file() and candidate.suffix.lower() in supported_ext:
                rp = candidate.resolve()
                if rp not in seen:
                    files.append(candidate)
                    seen.add(rp)

    return sorted(files)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Markdown documentation for SystemVerilog source, testbench, package, and include files."
    )
    parser.add_argument("inputs", nargs="+", help="Input files, directories, or glob patterns")
    parser.add_argument("-o", "--output", default=None, help="Output directory for generated docs")
    parser.add_argument("--no-svg", action="store_true", help="Disable top IO SVG generation")
    parser.add_argument("--no-recursive", action="store_true", help="Do not recurse when input is a directory")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    inputs = list(args.inputs)
    output_arg = args.output

    # Backward-compatible mode:
    #   python sv_documenter.py <input_file> <output_dir>
    # If -o/--output is not provided and the last positional arg is a directory,
    # treat it as output only when preceding positional args are files.
    if output_arg is None and len(inputs) >= 2:
        last_path = Path(inputs[-1])
        prev_are_files = all(Path(item).is_file() for item in inputs[:-1])
        if last_path.is_dir() and prev_are_files:
            output_arg = inputs[-1]
            inputs = inputs[:-1]

    # Default output is the current directory when no output arg is provided.
    if output_arg is None:
        output_dir = Path(".")
    else:
        output_dir = Path(output_arg)

    recursive = not args.no_recursive

    files = collect_input_files(inputs, recursive=recursive)
    if not files:
        print("No supported SystemVerilog files found.")
        return 1

    generated: List[Path] = []
    for sv_file in files:
        model = build_document_model(sv_file)
        out = render_markdown(model, output_dir, emit_svg=not args.no_svg)
        generated.append(out)
        print(f"Generated: {out}")

    print(f"Done. Generated {len(generated)} document(s) in {output_dir}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
