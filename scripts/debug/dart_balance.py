# -*- coding: utf-8 -*-
"""Точная проверка баланса скобок в Dart-файлах (учитывает строки, интерполяцию, комментарии)."""
import io
import sys

BS = chr(92)  # backslash


def analyze(path):
    s = io.open(path, encoding="utf-8").read()
    i = 0
    n = len(s)
    line = 1
    stack = []
    while i < n:
        c = s[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            while i < n and s[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "*":
            i += 2
            while i + 1 < n and not (s[i] == "*" and s[i + 1] == "/"):
                if s[i] == "\n":
                    line += 1
                i += 1
            i += 2
            continue
        if c in "'\"":
            q = c
            raw = i > 0 and s[i - 1] == "r"
            triple = s[i:i + 3] == q * 3
            if triple:
                i += 3
                while i < n and s[i:i + 3] != q * 3:
                    if s[i] == "\n":
                        line += 1
                    if not raw and s[i] == BS:
                        i += 1
                    elif not raw and s[i] == "$" and i + 1 < n and s[i + 1] == "{":
                        d = 1
                        i += 2
                        while i < n and d > 0:
                            if s[i] == "{":
                                d += 1
                            elif s[i] == "}":
                                d -= 1
                            elif s[i] == "\n":
                                line += 1
                            i += 1
                        continue
                    i += 1
                i += 3
                continue
            else:
                i += 1
                while i < n and s[i] != q and s[i] != "\n":
                    if not raw and s[i] == BS:
                        i += 1
                    elif not raw and s[i] == "$" and i + 1 < n and s[i + 1] == "{":
                        d = 1
                        i += 2
                        while i < n and d > 0:
                            if s[i] == "{":
                                d += 1
                            elif s[i] == "}":
                                d -= 1
                            elif s[i] == "\n":
                                line += 1
                            i += 1
                        continue
                    i += 1
                i += 1
                continue
        if c in "{([":
            stack.append((c, line))
        elif c in "})]":
            if not stack:
                print(path, "UNMATCHED closing", c, "at line", line)
            else:
                o, ol = stack.pop()
                if {"}": "{", ")": "(", "]": "["}[c] != o:
                    print(path, "MISMATCH", o, "line", ol, "closed by", c, "line", line)
        i += 1
    ok = True
    for o, ol in stack:
        print(path, "UNCLOSED", o, "opened at line", ol)
        ok = False
    if ok:
        print(path, "OK balanced")


for p in sys.argv[1:]:
    analyze(p)
