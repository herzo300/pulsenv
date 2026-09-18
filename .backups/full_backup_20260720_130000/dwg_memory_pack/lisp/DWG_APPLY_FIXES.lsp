;;; DWG_APPLY_FIXES.lsp
;;; Helper functions for applying generated DWG Memory fixes.
;;; Load this file first, then load a generated apply_*.lsp file.

(vl-load-com)

(defun dwgm:msg (s)
  (princ (strcat "\n[DWG Memory] " s))
)

(defun dwgm:entity (handle / en)
  (setq en (handent handle))
  (if (null en)
    (dwgm:msg (strcat "Entity not found: " handle))
  )
  en
)

(defun dwgm:ensure-layer (layer)
  (if (not (tblsearch "LAYER" layer))
    (progn
      (command "_.-LAYER" "_Make" layer "")
      (dwgm:msg (strcat "Created layer: " layer))
    )
  )
)

(defun DWGM:SET-LAYER-COLOR (layer color / rec obj)
  (if (tblsearch "LAYER" layer)
    (progn
      (setq obj (vla-item (vla-get-layers (vla-get-activedocument (vlax-get-acad-object))) layer))
      (vla-put-color obj color)
      (dwgm:msg (strcat "Layer color set: " layer))
    )
    (dwgm:msg (strcat "Layer not found: " layer))
  )
  (princ)
)

(defun DWGM:RENAME-LAYER (old new)
  (if (tblsearch "LAYER" old)
    (progn
      (command "_.-LAYER" "_Rename" old new "")
      (dwgm:msg (strcat "Layer renamed: " old " -> " new))
    )
    (dwgm:msg (strcat "Layer not found: " old))
  )
  (princ)
)

(defun DWGM:MOVE-ENTITY-TO-LAYER (handle layer / en data pair)
  (dwgm:ensure-layer layer)
  (setq en (dwgm:entity handle))
  (if en
    (progn
      (setq data (entget en))
      (setq pair (assoc 8 data))
      (if pair
        (setq data (subst (cons 8 layer) pair data))
        (setq data (append data (list (cons 8 layer))))
      )
      (entmod data)
      (entupd en)
      (dwgm:msg (strcat "Moved entity " handle " to layer " layer))
    )
  )
  (princ)
)

(defun DWGM:SET-ENTITY-COLOR (handle color / en data pair)
  (setq en (dwgm:entity handle))
  (if en
    (progn
      (setq data (entget en))
      (setq pair (assoc 62 data))
      (if pair
        (setq data (subst (cons 62 color) pair data))
        (setq data (append data (list (cons 62 color))))
      )
      (entmod data)
      (entupd en)
      (dwgm:msg (strcat "Entity color set: " handle))
    )
  )
  (princ)
)

(defun DWGM:SET-ENTITY-TEXT (handle value / en data pair typ)
  (setq en (dwgm:entity handle))
  (if en
    (progn
      (setq data (entget en))
      (setq typ (cdr (assoc 0 data)))
      (if (member typ (list "TEXT" "MTEXT" "ATTRIB" "ATTDEF" "DIMENSION"))
        (progn
          (setq pair (assoc 1 data))
          (if pair
            (setq data (subst (cons 1 value) pair data))
            (setq data (append data (list (cons 1 value))))
          )
          (entmod data)
          (entupd en)
          (dwgm:msg (strcat "Text set: " handle))
        )
        (dwgm:msg (strcat "Entity is not text-like: " handle))
      )
    )
  )
  (princ)
)

(defun DWGM:DELETE-ENTITY (handle / en)
  (setq en (dwgm:entity handle))
  (if en
    (progn
      (entdel en)
      (dwgm:msg (strcat "Deleted entity: " handle))
    )
  )
  (princ)
)

(defun c:DWG_APPLY_FIXES_HELP ()
  (dwgm:msg "Load a generated apply_*.lsp file after this helper.")
  (dwgm:msg "Available helpers: DWGM:SET-LAYER-COLOR, DWGM:RENAME-LAYER, DWGM:MOVE-ENTITY-TO-LAYER, DWGM:SET-ENTITY-COLOR, DWGM:SET-ENTITY-TEXT, DWGM:DELETE-ENTITY.")
  (princ)
)

(princ "\nDWG_APPLY_FIXES loaded. Run DWG_APPLY_FIXES_HELP or load a generated apply_*.lsp.")
(princ)
