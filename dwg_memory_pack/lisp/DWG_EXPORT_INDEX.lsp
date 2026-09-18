;;; DWG_EXPORT_INDEX.lsp
;;; Exports a DWG structure snapshot to JSON from inside AutoCAD.
;;; Command: DWG_EXPORT_INDEX

(vl-load-com)

(defun dwgm:json-escape (s / i ch out)
  (if (null s) (setq s ""))
  (setq s (vl-princ-to-string s))
  (setq out "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (cond
      ((= ch "\\") (setq out (strcat out "\\\\")))
      ((= ch "\"") (setq out (strcat out "\\\"")))
      ((= ch (chr 10)) (setq out (strcat out "\\n")))
      ((= ch (chr 13)) (setq out (strcat out "\\r")))
      ((= ch (chr 9)) (setq out (strcat out "\\t")))
      (T (setq out (strcat out ch)))
    )
    (setq i (1+ i))
  )
  out
)

(defun dwgm:q (s)
  (strcat "\"" (dwgm:json-escape s) "\"")
)

(defun dwgm:num (n)
  (cond
    ((= (type n) 'INT) (itoa n))
    ((= (type n) 'REAL) (rtos n 2 10))
    (T "0")
  )
)

(defun dwgm:list-json (lst / first out)
  (setq out "[" first T)
  (foreach x lst
    (if first
      (setq first nil)
      (setq out (strcat out ","))
    )
    (setq out (strcat out (dwgm:value-json x)))
  )
  (strcat out "]")
)

(defun dwgm:ename-handle (e / d h)
  (setq d (entget e))
  (setq h (cdr (assoc 5 d)))
  (if h h (vl-princ-to-string e))
)

(defun dwgm:value-json (v / t)
  (setq t (type v))
  (cond
    ((null v) "null")
    ((= t 'STR) (dwgm:q v))
    ((or (= t 'INT) (= t 'REAL)) (dwgm:num v))
    ((= t 'ENAME) (dwgm:q (dwgm:ename-handle v)))
    ((= t 'LIST) (dwgm:list-json v))
    ((= t 'SYM) (dwgm:q (vl-princ-to-string v)))
    (T (dwgm:q (vl-princ-to-string v)))
  )
)

(defun dwgm:pair-json (pair)
  (strcat "{\"code\":" (itoa (car pair)) ",\"value\":" (dwgm:value-json (cdr pair)) "}")
)

(defun dwgm:getstr (code data)
  (cdr (assoc code data))
)

(defun dwgm:getjson (code data)
  (dwgm:value-json (cdr (assoc code data)))
)

(defun dwgm:write-groups (fh data / first pair)
  (write-line "\"groups\":[" fh)
  (setq first T)
  (foreach pair data
    (if first
      (setq first nil)
      (write-line "," fh)
    )
    (princ (dwgm:pair-json pair) fh)
  )
  (write-line "]" fh)
)

(defun dwgm:write-point-groups (fh data / first pair code)
  (write-line "\"points\":[" fh)
  (setq first T)
  (foreach pair data
    (setq code (car pair))
    (if (and (>= code 10) (<= code 18) (= (type (cdr pair)) 'LIST))
      (progn
        (if first
          (setq first nil)
          (write-line "," fh)
        )
        (princ (dwgm:pair-json pair) fh)
      )
    )
  )
  (write-line "]" fh)
)

(defun dwgm:attrib-json (en / d out first tag val handle)
  (setq out "[" first T)
  (setq en (entnext en))
  (while en
    (setq d (entget en))
    (cond
      ((= (cdr (assoc 0 d)) "SEQEND") (setq en nil))
      ((= (cdr (assoc 0 d)) "ATTRIB")
        (setq tag (cdr (assoc 2 d)))
        (setq val (cdr (assoc 1 d)))
        (setq handle (cdr (assoc 5 d)))
        (if first
          (setq first nil)
          (setq out (strcat out ","))
        )
        (setq out
          (strcat
            out
            "{\"handle\":" (dwgm:q handle)
            ",\"tag\":" (dwgm:q tag)
            ",\"text\":" (dwgm:q val)
            ",\"layer\":" (dwgm:q (cdr (assoc 8 d)))
            "}"
          )
        )
        (setq en (entnext en))
      )
      (T (setq en (entnext en)))
    )
  )
  (strcat out "]")
)

(defun dwgm:entity-json (en / d typ handle layer layout space color ltype name text)
  (setq d (entget en '("*")))
  (setq typ (cdr (assoc 0 d)))
  (setq handle (cdr (assoc 5 d)))
  (setq layer (cdr (assoc 8 d)))
  (setq layout (cdr (assoc 410 d)))
  (setq space (cdr (assoc 67 d)))
  (setq color (cdr (assoc 62 d)))
  (setq ltype (cdr (assoc 6 d)))
  (setq name (cdr (assoc 2 d)))
  (setq text (cdr (assoc 1 d)))
  (strcat
    "{"
    "\"handle\":" (dwgm:q handle)
    ",\"type\":" (dwgm:q typ)
    ",\"layer\":" (dwgm:q layer)
    ",\"layout\":" (dwgm:q layout)
    ",\"space\":" (if space (itoa space) "0")
    ",\"color\":" (if color (itoa color) "null")
    ",\"linetype\":" (if ltype (dwgm:q ltype) "null")
    ",\"name\":" (if name (dwgm:q name) "null")
    ",\"text\":" (if text (dwgm:q text) "null")
    ",\"attributes\":" (if (= typ "INSERT") (dwgm:attrib-json en) "[]")
    ","
  )
)

(defun dwgm:write-entity (fh en / d)
  (setq d (entget en '("*")))
  (princ (dwgm:entity-json en) fh)
  (dwgm:write-point-groups fh d)
  (write-line "," fh)
  (dwgm:write-groups fh d)
  (write-line "}" fh)
)

(defun dwgm:write-layers (fh / rec first)
  (write-line "\"layers\":[" fh)
  (setq rec (tblnext "LAYER" T))
  (setq first T)
  (while rec
    (if first
      (setq first nil)
      (write-line "," fh)
    )
    (princ
      (strcat
        "{\"name\":" (dwgm:q (cdr (assoc 2 rec)))
        ",\"flags\":" (dwgm:value-json (cdr (assoc 70 rec)))
        ",\"color\":" (dwgm:value-json (cdr (assoc 62 rec)))
        ",\"linetype\":" (dwgm:q (cdr (assoc 6 rec)))
        ",\"lineweight\":" (dwgm:value-json (cdr (assoc 370 rec)))
        "}"
      )
      fh
    )
    (setq rec (tblnext "LAYER"))
  )
  (write-line "]" fh)
)

(defun dwgm:write-blocks (fh / rec first)
  (write-line "\"blocks\":[" fh)
  (setq rec (tblnext "BLOCK" T))
  (setq first T)
  (while rec
    (if first
      (setq first nil)
      (write-line "," fh)
    )
    (princ
      (strcat
        "{\"name\":" (dwgm:q (cdr (assoc 2 rec)))
        ",\"flags\":" (dwgm:value-json (cdr (assoc 70 rec)))
        ",\"xref_path\":" (dwgm:value-json (cdr (assoc 1 rec)))
        ",\"origin\":" (dwgm:value-json (cdr (assoc 10 rec)))
        "}"
      )
      fh
    )
    (setq rec (tblnext "BLOCK"))
  )
  (write-line "]" fh)
)

(defun dwgm:write-layouts (fh / rec first)
  (write-line "\"layouts\":[" fh)
  (setq rec (tblnext "LAYOUT" T))
  (setq first T)
  (while rec
    (if first
      (setq first nil)
      (write-line "," fh)
    )
    (princ
      (strcat
        "{\"name\":" (dwgm:q (cdr (assoc 1 rec)))
        ",\"tab_order\":" (dwgm:value-json (cdr (assoc 71 rec)))
        ",\"block_record\":" (dwgm:value-json (cdr (assoc 330 rec)))
        "}"
      )
      fh
    )
    (setq rec (tblnext "LAYOUT"))
  )
  (write-line "]" fh)
)

(defun dwgm:write-entities (fh / ss i en first)
  (write-line "\"entities\":[" fh)
  (setq ss (ssget "_X"))
  (setq first T)
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i))
        (if first
          (setq first nil)
          (write-line "," fh)
        )
        (dwgm:write-entity fh en)
        (setq i (1+ i))
      )
    )
  )
  (write-line "]" fh)
)

(defun c:DWG_EXPORT_INDEX (/ default path fh)
  (setq default
    (strcat
      (getvar "DWGPREFIX")
      (vl-filename-base (getvar "DWGNAME"))
      "_dwg_index.json"
    )
  )
  (setq path (getfiled "Save DWG index JSON" default "json" 1))
  (if path
    (progn
      (setq fh (open path "w"))
      (if fh
        (progn
          (write-line "{" fh)
          (write-line "\"format\":\"dwg-memory-index-v1\"," fh)
          (write-line "\"metadata\":{" fh)
          (write-line (strcat "\"dwgname\":" (dwgm:q (getvar "DWGNAME")) ",") fh)
          (write-line (strcat "\"dwgprefix\":" (dwgm:q (getvar "DWGPREFIX")) ",") fh)
          (write-line (strcat "\"acadver\":" (dwgm:q (getvar "ACADVER")) ",") fh)
          (write-line (strcat "\"insunits\":" (dwgm:value-json (getvar "INSUNITS")) ",") fh)
          (write-line (strcat "\"extmin\":" (dwgm:value-json (getvar "EXTMIN")) ",") fh)
          (write-line (strcat "\"extmax\":" (dwgm:value-json (getvar "EXTMAX")) ",") fh)
          (write-line (strcat "\"exported_cdate\":" (dwgm:value-json (getvar "CDATE"))) fh)
          (write-line "}," fh)
          (dwgm:write-layers fh)
          (write-line "," fh)
          (dwgm:write-blocks fh)
          (write-line "," fh)
          (dwgm:write-layouts fh)
          (write-line "," fh)
          (dwgm:write-entities fh)
          (write-line "}" fh)
          (close fh)
          (princ (strcat "\nDWG index exported: " path))
        )
        (princ "\nCould not open output file.")
      )
    )
    (princ "\nExport cancelled.")
  )
  (princ)
)

(princ "\nDWG_EXPORT_INDEX loaded. Run command: DWG_EXPORT_INDEX")
(princ)
